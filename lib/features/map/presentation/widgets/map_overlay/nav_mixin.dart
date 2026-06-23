part of '../map_overlay.dart';

mixin _NavOverlayMixin on ConsumerState<MapOverlay> {
  // ── Navigation state ───────────────────────────────────────────
  bool _navCameraFollow = true;
  bool _navCameraUpdating = false;
  double _lastNavBearing = 0.0;
  Position? _prevNavPosition;

  /// true = 북쪽 고정, false = 이동 방향 (기본, Mode B와 동일)
  bool _modeANorthUpMode = false;

  // 폴리라인 실시간 트리밍 캐시 (Mode B와 동일 패턴)
  NPolylineOverlay? _cachedModeANavPolyline;
  int _lastTrimModeAIdx = -1;
  bool _lastTrimModeAOffRoute = false;

  // ── Mode A walk/bike 방향 전환 안내 상태 ─────────────────────────
  List<_TurnPoint> _modeATurnPoints = [];
  int _modeARoadNearestPtIdx = 0;
  int _modeATurnMarkerCount = 0;

  NaverMapController? get _ctrl;
  Position? get _position;

  /// 기기 나침반 방위각 (_MapOverlayState._compassHeading으로 구현)
  double get _compassHeading;

  // ── Camera helpers ─────────────────────────────────────────────

  Future<void> _followNavCamera(double lat, double lng, double bearing) async {
    if (!_navCameraFollow || _ctrl == null) return;
    _navCameraUpdating = true;
    final update = NCameraUpdate.withParams(
      target: NLatLng(lat, lng),
      zoom: 17,
      bearing: bearing,
      tilt: 40,
    )..setAnimation(
        animation: NCameraAnimation.linear,
        duration: const Duration(milliseconds: 700),
      );
    await _ctrl!.updateCamera(update);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _navCameraUpdating = false;
    });
  }

  double _calcBearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng = (lng2 - lng1) * toRad;
    final y = sin(dLng) * cos(lat2 * toRad);
    final x = cos(lat1 * toRad) * sin(lat2 * toRad) -
        sin(lat1 * toRad) * cos(lat2 * toRad) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _clearModeANavCache() {
    _cachedModeANavPolyline = null;
    _lastTrimModeAIdx = -1;
    _lastTrimModeAOffRoute = false;
  }

  void _toggleModeANorthUpMode() {
    if (!mounted) return;
    setState(() => _modeANorthUpMode = !_modeANorthUpMode);
    final pos = _position;
    if (pos != null && _navCameraFollow) {
      final bearing = _modeANorthUpMode ? 0.0 : _lastNavBearing;
      _followNavCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  Future<void> _recenterNav() async {
    if (!mounted) return;
    setState(() => _navCameraFollow = true);
    final pos = _position;
    if (pos != null) {
      final bearing = _modeANorthUpMode ? 0.0 : _compassHeading;
      await _followNavCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  Future<void> _resetNavCamera() async {
    if (_ctrl == null || _position == null) return;
    setState(() {
      _navCameraFollow = true;
      _navCameraUpdating = false;
      _lastNavBearing = 0.0;
      _prevNavPosition = null;
      _modeANorthUpMode = false;
    });
    _clearModeANavCache();
    await _ctrl!.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(_position!.latitude, _position!.longitude),
        zoom: 15,
        bearing: 0,
        tilt: 0,
      )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 600),
        ),
    );
  }

  // ── Mode A 폴리라인 실시간 트리밍 (Mode B _trimNavPolylineToRemaining와 동일 패턴) ──

  Future<void> _trimModeAPolylineToRemaining(Position p, ModeANavState navState) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    if (!navState.isNavigating) return;

    final route = ref.read(modeAProvider).routeResult;
    if (route == null || route.routePoints.isEmpty) return;
    // 대중교통은 구간별 폴리라인이므로 트리밍 생략
    if (route.transport == 'transit') return;

    final startIdx = navState.nearestPtIdx;
    final isOffRoute = navState.isOffRoute;

    // 인덱스도 이탈 상태도 바뀌지 않았으면 갱신 불필요
    if (startIdx == _lastTrimModeAIdx && isOffRoute == _lastTrimModeAOffRoute) return;
    if (startIdx <= 0) return;
    if (startIdx >= route.routePoints.length - 1) return;

    final trimmed = route.routePoints
        .sublist(startIdx)
        .map((pt) => NLatLng(pt.latitude, pt.longitude))
        .toList();
    if (trimmed.length < 2) return;

    // context 의존 값은 첫 await 전에 캡처
    final offRouteColor = context.colors.warn;
    final c = context.colors;
    final routeColor = route.transport == 'bike' ? c.warn : c.primary;
    final polylineColor = isOffRoute ? offRouteColor : routeColor;

    final cached = _cachedModeANavPolyline;
    if (cached != null) {
      if (startIdx != _lastTrimModeAIdx) cached.setCoords(trimmed);
      if (isOffRoute != _lastTrimModeAOffRoute) cached.setColor(polylineColor);
    } else {
      await ctrl.deleteOverlay(
        const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'mode_a_route'),
      ).catchError((_) {});
      if (!mounted) return;
      final poly = NPolylineOverlay(
        id: 'mode_a_route',
        coords: trimmed,
        color: polylineColor,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      );
      await ctrl.addOverlay(poly);
      if (mounted) _cachedModeANavPolyline = poly;
    }

    _lastTrimModeAIdx = startIdx;
    _lastTrimModeAOffRoute = isOffRoute;
  }

  // ── Mode A 네비 플로팅 버튼 (나침반 토글 + 재센터, Mode B와 동일 레이아웃) ──

  List<Widget> _buildModeANavFloatingButtons(double bottomPad) {
    return [
      // 나침반 버튼 (탭하면 north-up / heading-up 전환)
      Positioned(
        right: 12,
        bottom: 96 + bottomPad + 16 + 56,
        child: GestureDetector(
          onTap: _toggleModeANorthUpMode,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _modeANorthUpMode ? context.colors.pinUser : kMapPanel,
              shape: BoxShape.circle,
              border: Border.all(
                color: _modeANorthUpMode
                    ? context.colors.pinUser
                    : Colors.white24,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: _modeANorthUpMode ? 0 : -_lastNavBearing * (pi / 180),
                child: Icon(
                  Icons.navigation_rounded,
                  size: 22,
                  color: _modeANorthUpMode ? Colors.white : kMapWhite87,
                ),
              ),
            ),
          ),
        ),
      ),
      // 재센터 버튼 (카메라 팔로우 해제 시)
      if (!_navCameraFollow)
        Positioned(
          right: 12,
          bottom: 96 + bottomPad + 16,
          child: GestureDetector(
            onTap: _recenterNav,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.pinUser,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.my_location_rounded, size: 22, color: Colors.white),
            ),
          ),
        ),
    ];
  }

  // ── Mode A walk/bike 방향 전환 포인트 계산 및 관리 ─────────────────────────

  /// Mode B의 _computeTurnPoints와 동일한 알고리즘 (routePoints 기반)
  List<_TurnPoint> _computeModeATurnPoints(List<LatLng> pts) {
    if (pts.length < 6) return [];

    final cumDist = List<double>.filled(pts.length, 0.0);
    for (int i = 1; i < pts.length; i++) {
      cumDist[i] = cumDist[i - 1] +
          _fastDistM(pts[i - 1].latitude, pts[i - 1].longitude,
              pts[i].latitude, pts[i].longitude);
    }
    final totalDist = cumDist.last;
    if (totalDist < 50) return [];

    const segLen = 25.0;
    const turnThreshold = 25.0;
    const uTurnThreshold = 120.0;
    const minDistSpacing = 40.0;

    final turns = <_TurnPoint>[];
    double lastTurnDist = -minDistSpacing;

    for (int i = 0; i < pts.length; i++) {
      final d = cumDist[i];
      if (d < segLen || d > totalDist - segLen) continue;

      int iA = i;
      while (iA > 0 && cumDist[iA] > d - segLen) { iA--; }
      int iL = i;
      while (iL < pts.length - 1 && cumDist[iL] < d + segLen) { iL++; }
      if (iA == i || iL == i) continue;

      final approachBearing = _bearingDeg(
          pts[iA].latitude, pts[iA].longitude, pts[i].latitude, pts[i].longitude);
      final leaveBearing = _bearingDeg(
          pts[i].latitude, pts[i].longitude, pts[iL].latitude, pts[iL].longitude);

      double delta = leaveBearing - approachBearing;
      while (delta > 180) { delta -= 360; }
      while (delta < -180) { delta += 360; }
      final absD = delta.abs();

      if (absD > turnThreshold && d - lastTurnDist >= minDistSpacing) {
        final type = absD >= uTurnThreshold
            ? _TurnType.uTurn
            : delta > 0 ? _TurnType.right : _TurnType.left;
        final instruction = absD >= uTurnThreshold
            ? '유턴하세요'
            : delta > 0 ? '오른쪽 길로 계속 진행' : '왼쪽 길로 계속 진행';
        turns.add(_TurnPoint(
          type: type, gpxIdx: i,
          lat: pts[i].latitude, lng: pts[i].longitude,
          instruction: instruction,
        ));
        lastTurnDist = d;
      }
    }

    turns.add(_TurnPoint(
      type: _TurnType.arrival, gpxIdx: pts.length - 1,
      lat: pts.last.latitude, lng: pts.last.longitude,
      instruction: '목적지에 도착합니다',
    ));

    debugPrint('[ModeA TurnDetect] pts=${pts.length} totalDist=${totalDist.round()}m turns=${turns.length - 1}');
    return turns;
  }

  void _initModeATurnPoints(RouteResultEntity route) {
    if (route.routePoints.isEmpty) { _modeATurnPoints = []; return; }
    _modeATurnPoints = _computeModeATurnPoints(route.routePoints);
    _modeARoadNearestPtIdx = 0;
  }

  _TurnPoint? _getModeACurrentTurn() {
    for (final t in _modeATurnPoints) {
      if (t.gpxIdx > _modeARoadNearestPtIdx) return t;
    }
    return _modeATurnPoints.isNotEmpty ? _modeATurnPoints.last : null;
  }

  String _getModeADistToNextTurnLabel(List<LatLng> pts) {
    if (_modeATurnPoints.isEmpty || pts.isEmpty) return '';
    final nextTurn = _getModeACurrentTurn();
    if (nextTurn == null) return '';
    final endIdx = nextTurn.gpxIdx.clamp(0, pts.length - 1);
    var dist = 0.0;
    for (int i = _modeARoadNearestPtIdx; i < endIdx && i < pts.length - 1; i++) {
      dist += _fastDistM(pts[i].latitude, pts[i].longitude,
          pts[i + 1].latitude, pts[i + 1].longitude);
    }
    return dist < 1000 ? '${dist.round()}m' : '${(dist / 1000).toStringAsFixed(1)}km';
  }

  void _updateModeARoadNearestPtIdx(double lat, double lng, RouteResultEntity route) {
    final pts = route.routePoints;
    if (pts.isEmpty) return;
    final searchEnd = pts.length.clamp(0, _modeARoadNearestPtIdx + 200);
    int best = _modeARoadNearestPtIdx;
    double bestDist = double.infinity;
    for (int i = _modeARoadNearestPtIdx; i < searchEnd; i++) {
      final d = _fastDistM(lat, lng, pts[i].latitude, pts[i].longitude);
      if (d < bestDist) { bestDist = d; best = i; }
    }
    if (best > _modeARoadNearestPtIdx) _modeARoadNearestPtIdx = best;
  }

  Future<void> _drawModeAWalkTurnMarkers(List<_TurnPoint> turns) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    for (int i = 0; i < _modeATurnMarkerCount; i++) {
      ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: 'ma_turn_$i'),
      ).catchError((_) {});
    }
    _modeATurnMarkerCount = 0;

    final ctx = context;
    int idx = 0;
    for (final turn in turns) {
      if (turn.type == _TurnType.straight || turn.type == _TurnType.arrival) continue;
      if (!mounted) break;
      final icon = await NOverlayImage.fromWidget(
        widget: _TurnDirectionMarker(type: turn.type),
        size: const Size(28, 28),
        context: ctx,
      );
      if (!mounted) break;
      await ctrl.addOverlay(NMarker(
        id: 'ma_turn_$idx',
        position: NLatLng(turn.lat, turn.lng),
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
      idx++;
    }
    _modeATurnMarkerCount = idx;
  }

  Future<void> _clearModeAWalkTurnMarkers() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (int i = 0; i < _modeATurnMarkerCount; i++) {
      ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: 'ma_turn_$i'),
      ).catchError((_) {});
    }
    _modeATurnMarkerCount = 0;
  }

  void _resetModeAWalkTurnState() {
    _modeATurnPoints = [];
    _modeARoadNearestPtIdx = 0;
  }

  // ── Guide direction marker (next turn point on map) ───────────────────────

  Future<void> _updateNavGuideMarker(RouteGuide? guide) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    await ctrl
        .deleteOverlay(
          const NOverlayInfo(type: NOverlayType.marker, id: 'nav_guide_arrow'),
        )
        .catchError((_) {});
    if (guide == null || guide.isArrival) return;

    final icon = await NOverlayImage.fromWidget(
      widget: _GuideDirectionMarker(type: guide.type, guidance: guide.guidance),
      size: const Size(48, 48),
      context: context, // ignore: use_build_context_synchronously
    );
    if (!mounted) return;

    await ctrl.addOverlay(
      NMarker(
        id: 'nav_guide_arrow',
        position: NLatLng(guide.latitude, guide.longitude),
        icon: icon,
      )..setZIndex(20),
    );
  }

  Future<void> _clearNavGuideMarker() async {
    await _ctrl
        ?.deleteOverlay(
          const NOverlayInfo(type: NOverlayType.marker, id: 'nav_guide_arrow'),
        )
        .catchError((_) {});
  }

  // ── Transit step markers ───────────────────────────────────────

  int _transitStepMarkerCount = 0;

  Future<void> _drawTransitStepMarkers(
      RouteResultEntity result, int activeIdx) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    for (int i = 0; i < _transitStepMarkerCount; i++) {
      ctrl
          .deleteOverlay(
              NOverlayInfo(type: NOverlayType.marker, id: 'transit_step_$i'))
          .catchError((_) {});
    }

    final steps = result.transitSteps;
    if (steps.isEmpty) {
      _transitStepMarkerCount = 0;
      return;
    }

    final ctx = context;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final lat = step.startLat;
      final lng = step.startLng;
      if (lat == null || lng == null) continue;

      final isActive = i == activeIdx;
      final isDone   = i < activeIdx;

      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: step.trafficType,
          lineInfo: step.lineInfo,
          isActive: isActive,
          isDone: isDone,
        ),
        size: isActive ? const Size(52, 52) : const Size(36, 36),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;

      final captionText = step.isWalk
          ? (i == 0 ? '출발' : '${step.startName} 도보')
          : (step.lineInfo != null ? '${step.lineInfo} 승차' : step.startName);

      final captionColor = isActive
          ? (step.isBus ? kMapGreen : context.colors.pinUser)
          : Colors.white54;

      final marker = NMarker(
        id: 'transit_step_$i',
        position: NLatLng(lat, lng),
        icon: icon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: isActive ? 12 : 10,
          color: captionColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: !isActive,
      )..setZIndex(isActive ? 10 : 0);
      await ctrl.addOverlay(marker);
    }

    final lastStep = steps.last;
    if (lastStep.endLat != null && lastStep.endLng != null) {
      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: 0,
          lineInfo: null,
          isActive: activeIdx >= steps.length - 1,
          isDone: false,
        ),
        size: const Size(40, 40),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;
      final marker = NMarker(
        id: 'transit_step_${steps.length}',
        position: NLatLng(lastStep.endLat!, lastStep.endLng!),
        icon: icon,
        caption: NOverlayCaption(
          text: '도착 · ${result.toName}',
          textSize: 11,
          color: context.colors.danger,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      )..setZIndex(5);
      await ctrl.addOverlay(marker);
    }
    _transitStepMarkerCount = steps.length + 1;
  }
}
