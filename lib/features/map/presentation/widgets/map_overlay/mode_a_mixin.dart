part of '../map_overlay.dart';

mixin _ModeAOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode A state ───────────────────────────────────────────────
  final _sheetACtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _routeMarkerIcons;
  final Map<int, NOverlayImage> _nearbyIconCache = {};
  int _nearbyMarkerCount = 0;
  int _transitSegPolylineCount = 0;
  int _modeAArrowCount = 0;
  int _modeAGuideMarkerCount = 0;
  bool _modeAMapFocus = false;
  bool _routePanelEditing = false;

  /// 도착 다이얼로그 응답 대기 중 — true인 동안은 네비 종료 리스너가
  /// routeResult를 지우지 않는다(다이얼로그가 식당 목록을 참조해야 하므로).
  bool _modeAArrivalDialogPending = false;

  // 대중교통 폴리라인 실시간 트리밍 캐시
  final Map<int, NPolylineOverlay> _transitNavPolylines = {};
  int _lastTransitTrimStep = -1;
  int _lastTransitNearestPt = -1;
  bool _isTrimmingTransit = false;

  void _disposeModeA() {
    _sheetACtrl.dispose();
    _nearbyIconCache.clear();
    _clearTransitNavPolylines();
    // 안내가 시작되지 않은 상태(출발/도착/경유지를 고르는 계획 단계)에서 지도
    // 화면을 나가면 그 선택은 휘발성 데이터로 취급해 초기화한다 — 다음 진입 시
    // 처음부터 다시 고르게 한다. 안내가 이미 시작된 경우는 splash_screen의
    // 강제종료 복원 대상이므로 건드리지 않는다.
    if (!ref.read(modeANavProvider).isNavigating) {
      ref.read(modeAProvider.notifier).clearAll();
    }
  }

  /// "종료" 버튼/뒤로가기로 안내를 도중에 중단할 때 호출 — 도착이 아니라 사용자가
  /// 직접 끝낸 경우다. stop()이 elapsedKcal을 0으로 리셋하기 전에 값을 캡처해,
  /// 자전거 구간만 홈 화면 "오늘" 총합에 병합한다(도보는 페도미터가 이미 세고
  /// 있어 중복 방지 차원에서 제외). 대중교통은 도보+차량이 섞여 실측 kcal
  /// 트래킹이 없으므로(updateKcal 미호출) 도중 종료 시 병합할 신뢰할 값이 없어
  /// 건너뛴다 — 정상 도착 시에만(map_overlay.dart의 도착 리스너) 사전 추정치를 반영한다.
  void _cancelModeANav() {
    final route = ref.read(modeAProvider).routeResult;
    final navState = ref.read(modeANavProvider);
    if (route != null && route.transport == 'bike' && navState.elapsedKcal > 0) {
      final totalM = route.distanceKm * 1000;
      final traveledM = (totalM - navState.remainingDistanceM).clamp(0.0, totalM);
      ref
          .read(walkSessionProvider.notifier)
          .addExternalKcal(kcal: navState.elapsedKcal, distanceM: traveledM);
    }
    ref.read(modeANavProvider.notifier).stop();
  }

  void _clearTransitNavPolylines() {
    _transitNavPolylines.clear();
    _lastTransitTrimStep = -1;
    _lastTransitNearestPt = -1;
  }

  // Abstract dependencies
  NaverMapController? get _ctrl;
  Position? get _position;
  bool get _locating;
  set _locating(bool value);
  Future<void> _drawTransitStepMarkers(RouteResultEntity result, int activeIdx);
  void _clearModeATransitStepMarkers();
  Future<void> _resetNavCamera();
  TurnPoint? _getModeACurrentTurn();
  String _getModeADistToNextTurnLabel(List<LatLng> pts);
  bool get _modeANavStepMode;
  set _modeANavStepMode(bool v);
  bool get _modeATransitNavStepMode;
  set _modeATransitNavStepMode(bool v);
  void _initModeATurnPoints(RouteResultEntity route);
  List<TurnPoint> get _allModeATurnMarkers;
  Future<void> _drawModeATurnMarkers(List<TurnPoint> turns);
  Future<void> _clearModeAWalkTurnMarkers();
  Future<void> _drawModeASegmentsOnMap(
    RouteResultEntity route,
    int currentLegIdx,
  );
  Future<bool> _showModeAExitNavConfirmDialog();

  // ── Map focus toggle ───────────────────────────────────────────

  void _onModeAMapTap() {
    if (!mounted) return;
    setState(() => _modeAMapFocus = !_modeAMapFocus);
  }

  void _resetModeAFocusState() {
    if (mounted && (_modeAMapFocus || _routePanelEditing)) {
      setState(() {
        _modeAMapFocus = false;
        _routePanelEditing = false;
      });
    }
  }

  // ── Marker icons ───────────────────────────────────────────────

  Future<Map<String, NOverlayImage>> _getRouteMarkerIcons() async {
    if (_routeMarkerIcons != null) return _routeMarkerIcons!;
    final c = context.colors;
    final originIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.success, label: 'A'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final destIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.danger, label: 'B'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final wpIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.accent, label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    _routeMarkerIcons = {
      'origin': originIcon,
      'dest': destIcon,
      'waypoint': wpIcon,
    };
    return _routeMarkerIcons!;
  }

  Future<void> _syncModeAMarkers(ModeAState s) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = context.colors;
    const ids = ['wp_origin', 'wp_dest', 'wp_0', 'wp_1', 'wp_2'];
    for (final id in ids) {
      try {
        await ctrl.deleteOverlay(
          NOverlayInfo(type: NOverlayType.marker, id: id),
        );
      } catch (_) {}
    }
    final icons = await _getRouteMarkerIcons();
    if (!mounted) return;
    if (s.originLat != null && s.originLng != null) {
      await ctrl.addOverlay(
        NMarker(
          id: 'wp_origin',
          position: NLatLng(s.originLat!, s.originLng!),
          icon: icons['origin'],
          caption: NOverlayCaption(
            text: s.from,
            textSize: 11,
            color: c.success,
            haloColor: Colors.black87,
          ),
          captionOffset: 4,
          isHideCollidedCaptions: true,
        ),
      );
    }
    if (s.destLat != null && s.destLng != null) {
      await ctrl.addOverlay(
        NMarker(
          id: 'wp_dest',
          position: NLatLng(s.destLat!, s.destLng!),
          icon: icons['dest'],
          caption: NOverlayCaption(
            text: s.to,
            textSize: 11,
            color: c.danger,
            haloColor: Colors.black87,
          ),
          captionOffset: 4,
          isHideCollidedCaptions: true,
        ),
      );
    }
    for (var i = 0; i < s.waypoints.length; i++) {
      final wp = s.waypoints[i];
      await ctrl.addOverlay(
        NMarker(
          id: 'wp_$i',
          position: NLatLng(wp.latitude, wp.longitude),
          icon: icons['waypoint'],
          caption: NOverlayCaption(
            text: wp.name,
            textSize: 11,
            color: c.accent,
            haloColor: Colors.black87,
          ),
          captionOffset: 4,
          isHideCollidedCaptions: true,
        ),
      );
    }
  }

  // ── 코스 재생성 시 이전 코스가 지도에 남는 버그 방지 ─────────────────────
  // _drawModeAPolyline은 겹쳐서(concurrent) 호출되면 안 된다: addOverlay/deleteOverlay
  // 호출 사이사이 await로 제어권이 넘어가는데, 그 틈에 새 호출이 같은 카운터 필드
  // (_modeAArrowCount 등)를 건드리면 두 호출의 삭제/추가 범위가 어긋나 이전 코스의
  // 폴리라인·화살표·마커가 지워지지 않고 남는다("코스 중복" 버그의 원인).
  // 아래 큐가 모든 호출을 순서대로 직렬 실행하고, 대기 중 더 최신 요청으로 대체된
  // 호출은 건너뛰어 낭비 없이 항상 최신 결과만 그려지게 한다.
  int _modeADrawToken = 0;
  Future<void> _modeADrawChain = Future.value();

  Future<void> _drawModeAPolyline(RouteResultEntity? result) {
    final myToken = ++_modeADrawToken;
    final prevChain = _modeADrawChain;
    final completer = Completer<void>();
    _modeADrawChain = completer.future;
    return prevChain.then((_) async {
      try {
        if (myToken != _modeADrawToken || !mounted) return;
        await _drawModeAPolylineImpl(result);
      } finally {
        completer.complete();
      }
    });
  }

  Future<void> _drawModeAPolylineImpl(RouteResultEntity? result) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = context.colors;

    // 이전 대중교통 구간 폴리라인 제거
    for (var i = 0; i < _transitSegPolylineCount; i++) {
      ctrl
          .deleteOverlay(
            NOverlayInfo(
              type: NOverlayType.polylineOverlay,
              id: 'transit_seg_$i',
            ),
          )
          .catchError((_) {});
    }
    _transitSegPolylineCount = 0;

    // 이전 화살표·방향 마커 제거
    await _clearModeADecorations();

    // 이전 대중교통 스텝 마커(출발/환승/도착 아이콘) 제거 — 새 경로가 transit이
    // 아니면 아래에서 _drawTransitStepMarkers가 호출되지 않아 그 안의 정리 로직도
    // 실행되지 않으므로, 전송수단과 무관하게 여기서 항상 지운다.
    _clearModeATransitStepMarkers();

    await ctrl
        .deleteOverlay(
          const NOverlayInfo(
            type: NOverlayType.polylineOverlay,
            id: 'mode_a_route',
          ),
        )
        .catchError((_) {});
    if (result == null || result.routePoints.isEmpty) {
      unawaited(_clearModeAWalkTurnMarkers());
      return;
    }

    final coords = result.routePoints
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();

    if (result.transport == 'transit') {
      // 도보·버스·지하철 구분 없이 노란색 하나로 통일 — "코스생성"과 "안내시작"이 항상
      // 같은 폴리라인 오버레이 객체를 이어받으므로(map_overlay.dart의 nav-start 리스너가
      // 더 이상 _transitNavPolylines를 비우지 않음) 색도 자연히 통일된다.
      // step index를 polyline id로 사용해 실시간 트리밍 가능하게 함
      _clearTransitNavPolylines();
      bool anyDrawn = false;
      for (int stepIdx = 0; stepIdx < result.transitSteps.length; stepIdx++) {
        final step = result.transitSteps[stepIdx];
        if (step.stepPoints.length < 2) continue;
        final segCoords = step.stepPoints
            .map((p) => NLatLng(p.latitude, p.longitude))
            .toList();
        final poly = NPolylineOverlay(
          id: 'transit_seg_$stepIdx',
          coords: segCoords,
          color: _kTransit,
          width: step.isWalk ? 4 : 6,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        );
        await ctrl.addOverlay(poly);
        _transitNavPolylines[stepIdx] = poly;
        if (step.isWalk) {
          await _drawModeARouteArrows(segCoords, _kTransit);
        }
        anyDrawn = true;
      }
      _transitSegPolylineCount = result.transitSteps.length;

      if (!anyDrawn) {
        // stepPoints 없는 폴백: 단색 폴리라인
        await ctrl.addOverlay(
          NPolylineOverlay(
            id: 'mode_a_route',
            coords: coords,
            color: _kTransit,
            width: 5,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          ),
        );
        await _drawModeARouteArrows(coords, _kTransit);
      }
      if (result.transitSteps.isNotEmpty) {
        await _drawTransitStepMarkers(result, 0);
      }
    } else {
      // Mode B와 동일한 accent 색상 — 내비 시작 시 _drawModeASegmentsOnMap가
      // 구간별(ma_seg_$i)로 다시 그리므로 이 프리뷰 폴리라인은 미리보기 전용이다.
      final color = c.accent;
      await ctrl.addOverlay(
        NPolylineOverlay(
          id: 'mode_a_route',
          coords: coords,
          color: color,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
      await _drawModeARouteArrows(coords, color);
      await _drawModeAGuideMarkers(result.guides, result.transport);
    }

    if (mounted) {
      await MapCameraUtils.fitPoints(
        ctrl,
        coords,
        padding: const EdgeInsets.fromLTRB(60, 180, 60, 320),
      );
    }

    // 코스 생성(미리보기) 시점에도 좌우회전 턴마커를 표시 — 이동수단(도보/자전거/대중교통)
    // 구분은 _initModeATurnPoints가 route.transport로 알아서 분기한다.
    _initModeATurnPoints(result);
    if (_allModeATurnMarkers.any((t) => t.type != TurnType.arrival)) {
      unawaited(_drawModeATurnMarkers(_allModeATurnMarkers));
    } else {
      unawaited(_clearModeAWalkTurnMarkers());
    }
  }

  /// 앱 강제종료 후 재실행 복원 전용 — 안내 중이던 Mode A 경로를 지도에 다시 그린다
  /// (네트워크 호출 없이 순수 드로잉만. Mode B의 _restoreGeneratedCourseNav와 동격).
  Future<void> _restoreModeANavOnMap(
    RouteResultEntity route,
    ModeANavState navState,
  ) async {
    if (route.transport == 'transit') {
      // _drawModeAPolyline이 턴마커·트랜짓 스텝 마커까지 함께 그려준다.
      await _drawModeAPolyline(route);
      await _drawTransitStepMarkers(route, navState.currentTransitStepIdx);
    } else {
      _initModeATurnPoints(route);
      if (_allModeATurnMarkers.any((t) => t.type != TurnType.arrival)) {
        unawaited(_drawModeATurnMarkers(_allModeATurnMarkers));
      }
      if (route.segmentPolylines.isNotEmpty) {
        final legIdx = navState.currentLegIdx.clamp(
          0,
          route.segmentPolylines.length - 1,
        );
        await _drawModeASegmentsOnMap(route, legIdx);
      }
    }
  }

  /// 뒤로가기 스택이 비어 있을 수 있음(스플래시 복원으로 진입한 경우) — Mode B의
  /// _modeBSafeBack과 동일 패턴.
  void _modeASafeBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ── 대중교통 폴리라인 실시간 트리밍 (완전 실시간, 스로틀 없음) ──────────────

  Future<void> _trimModeATransitPolylines(
    Position p,
    ModeANavState navState,
  ) async {
    if (_isTrimmingTransit) return;
    _isTrimmingTransit = true;
    try {
      if (!mounted || !navState.isNavigating) return;
      final route = ref.read(modeAProvider).routeResult;
      if (route == null || route.transport != 'transit') return;

      final stepIdx = navState.currentTransitStepIdx;
      final steps = route.transitSteps;

      // 완료된 단계: 회색으로 변경
      for (int i = 0; i < stepIdx && i < steps.length; i++) {
        final poly = _transitNavPolylines[i];
        if (poly != null) {
          poly.setColor(Colors.white24);
          poly.setWidth(2);
        }
      }

      // 현재 단계: 이미 지나온 부분 트리밍
      if (stepIdx < steps.length) {
        final step = steps[stepIdx];
        final pts = step.stepPoints;
        if (pts.length >= 2) {
          // 이미 지나간 인덱스부터 앞으로 탐색 (단조 증가만 허용)
          var nearestIdx = _lastTransitNearestPt < 0
              ? 0
              : _lastTransitNearestPt.clamp(0, pts.length - 1);
          if (stepIdx != _lastTransitTrimStep) nearestIdx = 0;

          final searchEnd = (nearestIdx + 150).clamp(0, pts.length);
          double bestDist = double.infinity;
          for (int i = nearestIdx; i < searchEnd; i++) {
            final d = _fastDistM(
              p.latitude,
              p.longitude,
              pts[i].latitude,
              pts[i].longitude,
            );
            if (d < bestDist) {
              bestDist = d;
              nearestIdx = i;
            }
          }

          if (nearestIdx != _lastTransitNearestPt ||
              stepIdx != _lastTransitTrimStep) {
            final poly = _transitNavPolylines[stepIdx];
            if (poly != null) {
              final remaining = pts
                  .sublist(nearestIdx)
                  .map((pt) => NLatLng(pt.latitude, pt.longitude))
                  .toList();
              if (remaining.length >= 2) poly.setCoords(remaining);
            }
            _lastTransitNearestPt = nearestIdx;
            _lastTransitTrimStep = stepIdx;
          }
        }
      }
    } finally {
      _isTrimmingTransit = false;
    }
  }

  // ── Mode A 지오 헬퍼 (core/utils의 공용 함수를 NLatLng 시그니처로 감쌈) ──────

  static double _modeATotalLen(List<NLatLng> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += haversineDistanceM(
        pts[i - 1].latitude,
        pts[i - 1].longitude,
        pts[i].latitude,
        pts[i].longitude,
      );
    }
    return total;
  }

  static ({NLatLng pos, double bearing})? _modeAPointAtDist(
    List<NLatLng> pts,
    double dist,
  ) {
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final seg = haversineDistanceM(
        pts[i - 1].latitude,
        pts[i - 1].longitude,
        pts[i].latitude,
        pts[i].longitude,
      );
      if (acc + seg >= dist) {
        final t = (dist - acc) / seg;
        final lat =
            pts[i - 1].latitude + t * (pts[i].latitude - pts[i - 1].latitude);
        final lng =
            pts[i - 1].longitude +
            t * (pts[i].longitude - pts[i - 1].longitude);
        return (
          pos: NLatLng(lat, lng),
          bearing: bearingDeg(
            pts[i - 1].latitude,
            pts[i - 1].longitude,
            pts[i].latitude,
            pts[i].longitude,
          ),
        );
      }
      acc += seg;
    }
    return null;
  }

  // ── 화살표·방향 마커 초기화 ────────────────────────────────────────

  Future<void> _clearModeADecorations() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (var i = 0; i < _modeAArrowCount; i++) {
      ctrl
          .deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: 'mode_a_arrow_$i'),
          )
          .catchError((_) {});
    }
    _modeAArrowCount = 0;
    for (var i = 0; i < _modeAGuideMarkerCount; i++) {
      ctrl
          .deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: 'mode_a_guide_$i'),
          )
          .catchError((_) {});
    }
    _modeAGuideMarkerCount = 0;
  }

  // ── 폴리라인 위 방향 화살표 (Mode B _drawRouteArrows와 독립 구현) ──

  Future<void> _drawModeARouteArrows(List<NLatLng> points, Color color) async {
    final ctrl = _ctrl;
    if (ctrl == null || points.length < 2 || !mounted) return;

    final totalLen = _modeATotalLen(points);
    if (totalLen < 80) return;

    final count = (totalLen / 100).clamp(3.0, 25.0).round();
    final spacing = totalLen / (count + 1);
    var idx = _modeAArrowCount;

    for (var n = 1; n <= count; n++) {
      final result = _modeAPointAtDist(points, spacing * n);
      if (result == null) continue;
      if (!mounted) break;

      final icon = await NOverlayImage.fromWidget(
        widget: _RouteArrowIcon(bearingDeg: result.bearing, color: color),
        size: const Size(16, 16),
        context: context,
      );
      if (!mounted) break;

      await ctrl.addOverlay(
        NMarker(
          id: 'mode_a_arrow_$idx',
          position: result.pos,
          icon: icon,
          anchor: const NPoint(0.5, 0.5),
          isHideCollidedMarkers: false,
        ),
      );
      idx++;
    }
    _modeAArrowCount = idx;
  }

  // ── 교차로 방향 마커 (Kakao 안내 포인트 기반) ─────────────────────

  Future<void> _drawModeAGuideMarkers(
    List<RouteGuide> guides,
    String transport,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || guides.isEmpty || !mounted) return;

    final accentColor = transport == 'bike'
        ? context.colors.warn
        : context.colors.primary;
    var idx = 0;

    for (final guide in guides) {
      // 유의미한 회전만 표시: 우회전(12), 좌회전(13), 유턴(14), 횡단보도
      final isTurn = guide.type == 12 || guide.type == 13 || guide.type == 14;
      final isCrosswalk = guide.guidance.contains('횡단보도');
      if (!isTurn && !isCrosswalk) continue;
      if (!mounted) break;

      final icon = await NOverlayImage.fromWidget(
        widget: _ModeAGuidePin(
          type: guide.type,
          guidance: guide.guidance,
          color: accentColor,
        ),
        size: const Size(28, 28),
        context: context,
      );
      if (!mounted) break;

      await ctrl.addOverlay(
        NMarker(
          id: 'mode_a_guide_$idx',
          position: NLatLng(guide.latitude, guide.longitude),
          icon: icon,
          anchor: const NPoint(0.5, 0.5),
          isHideCollidedMarkers: false,
        ),
      );
      idx++;
    }
    _modeAGuideMarkerCount = idx;
  }

  Future<void> _fetchGpsOriginForModeA() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      final pos = _position ?? await fetchMapPosition();
      if (!mounted || pos == null) return;
      ref
          .read(modeAProvider.notifier)
          .setOriginGps(pos.latitude, pos.longitude, '현재 위치');
      await _ctrl?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 14,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Mode A dialogs / sheets ────────────────────────────────────

  Future<String?> _reverseGeocode(double lat, double lng) =>
      ref.read(placeRepositoryProvider).reverseGeocode(lat, lng);

  Future<void> _showLongPressSheet(NLatLng latLng) async {
    final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
    final locationName = address ?? '선택한 위치';
    if (!mounted) return;
    final modeAState = ref.read(modeAProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LongPressSheet(
        latLng: latLng,
        locationName: locationName,
        canAddWaypoint: modeAState.waypoints.length < 3,
        onSetOrigin: () {
          Navigator.pop(context);
          ref
              .read(modeAProvider.notifier)
              .setOriginGps(latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onSetDest: () {
          Navigator.pop(context);
          ref
              .read(modeAProvider.notifier)
              .setDestCoords(latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onAddWaypoint: () {
          Navigator.pop(context);
          ref
              .read(modeAProvider.notifier)
              .addWaypoint(
                RouteWaypoint(
                  name: locationName,
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                ),
              );
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
      ),
    );
  }

  Future<void> _onModeASearch() async {
    FocusScope.of(context).unfocus();
    await ref.read(modeAProvider.notifier).search();
    if (mounted && ref.read(modeAProvider).routeResult != null) {
      setState(() => _routePanelEditing = false);
    }
  }

  /// 도착 시 실제 소모 kcal을 보여주고 "주변 맛집을 보실까요?" 확인 후 응답에 따라
  /// 처리한다. 폴리라인·출발/경유/도착지 정리는 map_overlay.dart의 도착 감지
  /// 리스너가 markArrived() 호출로 이미 처리했으므로, 여기선 다이얼로그 응답에 따른
  /// 화면 전환만 담당한다 — routeResult는 도착 요약 표시를 위해 계속 유지.
  void _showArrivalRestaurantDialog() {
    if (!mounted) {
      _modeAArrivalDialogPending = false;
      return;
    }
    final arrivalKcal = ref.read(modeAProvider).arrivalKcal?.round() ?? 0;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.flag_rounded, color: kMapPrimary, size: 22),
            SizedBox(width: 8),
            Text(
              '목적지에 도착했어요!',
              style: AppTypography.bodyLg.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          '수고하셨어요. 실제로 $arrivalKcal kcal를 소모했어요.\n주변 맛집을 보실까요?',
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w400,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '괜찮아요',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '볼래요',
              style: TextStyle(color: kMapPrimary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).then((showRestaurants) {
      _modeAArrivalDialogPending = false;
      if (!mounted) return;
      if (showRestaurants == true) {
        // food_catalog로 매칭된 맛집(RestaurantEntity)을 탐색 모드(MapMode.explore)
        // 지도에 그대로 보여준다 — 마커/목록시트/상세페이지는 탐색 모드 기존 구현을
        // 재사용(map_overlay.dart의 places 리스너가 마커·카메라 fit을 자동 처리).
        final s = ref.read(modeAProvider);
        final places = [
          for (final r in s.restaurants)
            PlaceEntity(
              id: r.id,
              name: r.name,
              latitude: r.latitude,
              longitude: r.longitude,
              address: r.address,
              phone: r.tel,
              category: '${r.menu} · ${r.kcal}kcal',
              source: PlaceSource.kakaoLocal,
            ),
        ];
        ref
            .read(mapSearchNotifierProvider.notifier)
            .setPlaces(
              places,
              centerLat: s.restaurants.isNotEmpty
                  ? s.restaurants.first.latitude
                  : null,
              centerLng: s.restaurants.isNotEmpty
                  ? s.restaurants.first.longitude
                  : null,
            );
        ref.read(modeAProvider.notifier).clearRouteResult();
        ref.read(mapModeProvider.notifier).set(MapMode.explore);
      } else {
        ref.read(modeAProvider.notifier).clearRouteResult();
        unawaited(_clearNearbyMarkers());
        context.go('/home');
      }
    });
  }

  void _showWaypointCandidateSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WaypointCandidateSheet(
        state: ref.read(modeAProvider),
        onAdd: (candidate) {
          Navigator.pop(ctx);
          ref
              .read(modeAProvider.notifier)
              .addWaypoint(
                RouteWaypoint(
                  name: candidate.name,
                  latitude: candidate.latitude,
                  longitude: candidate.longitude,
                ),
              );
        },
        onLoadMore: (extra) =>
            ref.read(modeAProvider.notifier).loadWaypointCandidates(extra),
      ),
    );
  }

  // ── Nearby markers ────────────────────────────────────────────

  Future<NOverlayImage?> _getNearbyIcon(Color color) async {
    final key = color.toARGB32();
    if (_nearbyIconCache.containsKey(key)) return _nearbyIconCache[key];
    if (!mounted) return null;
    final icon = await NOverlayImage.fromWidget(
      widget: MapMarkerDot(color: color),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return null;
    _nearbyIconCache[key] = icon;
    return icon;
  }

  Future<void> _clearNearbyMarkers() async {
    final ctrl = _ctrl;
    if (ctrl == null || _nearbyMarkerCount == 0) return;
    for (var i = 0; i < _nearbyMarkerCount; i++) {
      try {
        await ctrl.deleteOverlay(
          NOverlayInfo(type: NOverlayType.marker, id: 'nearby_$i'),
        );
      } catch (_) {}
    }
    _nearbyMarkerCount = 0;
  }

  Future<void> _updateNearbyMarkers(ModeAState s) async {
    await _clearNearbyMarkers();
    final ctrl = _ctrl;
    if (ctrl == null || s.routeResult == null) return;

    if (!mounted) return;
    final c = context.colors;
    final Color markerColor;
    final List<({String id, NLatLng pos, String name, Object item})> pins;

    switch (s.nearbyTab) {
      case ModeANearbyTab.restaurant:
        markerColor = c.pinFood;
        pins = [
          for (var i = 0; i < s.restaurants.length; i++)
            (
              id: 'nearby_$i',
              pos: NLatLng(
                s.restaurants[i].latitude,
                s.restaurants[i].longitude,
              ),
              name: s.restaurants[i].name,
              item: s.restaurants[i] as Object,
            ),
        ];
      case ModeANearbyTab.durunubi:
        markerColor = c.pinUser;
        pins = [
          for (var i = 0; i < s.nearbyDurunubi.length; i++)
            if (s.nearbyDurunubi[i].startLat != null &&
                s.nearbyDurunubi[i].startLng != null)
              (
                id: 'nearby_$i',
                pos: NLatLng(
                  s.nearbyDurunubi[i].startLat!,
                  s.nearbyDurunubi[i].startLng!,
                ),
                name: s.nearbyDurunubi[i].name,
                item: s.nearbyDurunubi[i] as Object,
              ),
        ];
      default:
        markerColor = c.pinSight;
        pins = [
          for (var i = 0; i < s.nearbyPlaces.length; i++)
            (
              id: 'nearby_$i',
              pos: NLatLng(
                s.nearbyPlaces[i].latitude,
                s.nearbyPlaces[i].longitude,
              ),
              name: s.nearbyPlaces[i].name,
              item: s.nearbyPlaces[i] as Object,
            ),
        ];
    }

    if (pins.isEmpty) return;
    final icon = await _getNearbyIcon(markerColor);
    if (!mounted) return;

    final markers = <NMarker>{};
    for (final pin in pins) {
      final m = NMarker(
        id: pin.id,
        position: pin.pos,
        icon: icon,
        caption: NOverlayCaption(
          text: pin.name,
          textSize: 11,
          color: markerColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      );
      final captured = pin.item;
      m.setOnTapListener((_) {
        if (!mounted) return;
        context.push('/place-detail', extra: captured);
      });
      markers.add(m);
    }
    _nearbyMarkerCount = markers.length;
    await ctrl.addOverlayAll(markers);
  }

  // ── Mode A overlay widgets ─────────────────────────────────────

  List<Widget> _buildModeAOverlays(
    BuildContext context,
    MapMode mode,
    ModeAState modeAState,
    ModeANavState navState,
    double bottomPad,
  ) {
    if (mode != MapMode.modeA) return const [];

    // 경로 입력 패널 표시 조건:
    // - 안내 중이면 절대 표시 안 함
    // - 경로 결과 없음(입력 중) → 표시
    // - 결과 있음 → 사용자가 명시적으로 수정 버튼 눌렀을 때만
    final showRoutePanel =
        !navState.isNavigating &&
        (modeAState.routeResult == null || _routePanelEditing);

    // 안내 중에는 지도 포커스(UI 숨김) 비활성
    final mapFocused = _modeAMapFocus && !navState.isNavigating;

    final children = <Widget>[
      // ── 경로 입력 패널 ──────────────────────────────────────
      if (showRoutePanel)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ModeARoutePanel(
            state: modeAState,
            locating: _locating,
            onTapOrigin: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text('출발지를 설정해주세요', style: AppTypography.label),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: kMapPanel,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                ),
              );
              ref.read(mapModeProvider.notifier).set(MapMode.explore);
            },
            onGpsOrigin: _fetchGpsOriginForModeA,
            onTapDest: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text('도착지를 설정해주세요', style: AppTypography.label),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: kMapPanel,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                ),
              );
              ref.read(mapModeProvider.notifier).set(MapMode.explore);
            },
            onClearDest: () =>
                ref.read(modeAProvider.notifier).setDestCoords(null, null, ''),
            onSetTransport: (t) =>
                ref.read(modeAProvider.notifier).setTransport(t),
            onRemoveWaypoint: (i) =>
                ref.read(modeAProvider.notifier).removeWaypoint(i),
            onReorderWaypoints: (o, n) =>
                ref.read(modeAProvider.notifier).reorderWaypoint(o, n),
            onSearch: (modeAState.originLat == null || modeAState.to.isEmpty)
                ? null
                : _onModeASearch,
            onResetAll: () {
              ref.read(modeAProvider.notifier).clearAll();
              _fetchGpsOriginForModeA();
            },
            onBack: _modeASafeBack,
          ),
        ),

      // ── 경로 수정 버튼 (결과 있을 때 패널 대신) ────────────────
      if (!showRoutePanel && !navState.isNavigating)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 12,
          child: GestureDetector(
            onTap: () {
              setState(() => _routePanelEditing = true);
              unawaited(_drawModeAPolyline(null));
              unawaited(_clearNearbyMarkers());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _kPanel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: _kWhite87),
                  SizedBox(width: 6),
                  Text(
                    '경로 수정',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _kWhite87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

      // ── 칼로리 위젯 (결과 시트 표시 중에만 — 패널 내부 헤더에도 있음) ──
      if (!showRoutePanel && !navState.isNavigating)
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 12,
          child: _KcalWidget(
            routeKcal: modeAState.hasArrived
                ? modeAState.arrivalKcal?.round()
                : modeAState.routeResult?.kcalBurn,
          ),
        ),

      // ── 결과 시트 (안내 중 아닐 때, 경로 수정 중이 아닐 때) ──────
      if (modeAState.routeResult != null &&
          !navState.isNavigating &&
          !_routePanelEditing)
        DraggableScrollableSheet(
          controller: _sheetACtrl,
          initialChildSize: 0.52,
          minChildSize: 0.15,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.15, 0.52, 0.85],
          builder: (ctx, sc) => _ModeAResultSheet(
            scrollController: sc,
            state: modeAState,
            onRestaurantTap: (r) => context.push('/place-detail', extra: r),
            onStartNavigation: () {
              ref
                  .read(modeANavProvider.notifier)
                  .start(modeAState.routeResult!);
            },
            onLoadCandidates: (extra) =>
                ref.read(modeAProvider.notifier).loadWaypointCandidates(extra),
            onAddWaypointCandidate: (candidate) {
              ref
                  .read(modeAProvider.notifier)
                  .addWaypoint(
                    RouteWaypoint(
                      name: candidate.name,
                      latitude: candidate.latitude,
                      longitude: candidate.longitude,
                    ),
                  );
              _showWaypointCandidateSheet(context);
            },
            onSwitchTab: (tab) =>
                ref.read(modeAProvider.notifier).switchNearbyTab(tab),
            onPlaceTap: (place) => context.push('/place-detail', extra: place),
            onDurunubiTap: (course) =>
                context.push('/place-detail', extra: course),
          ),
        ),

      // ── 안내 중: 상단 카드 + 하단 스트립 ──────────────────────
      if (navState.isNavigating) ...[
        if (modeAState.routeResult!.transport == 'transit') ...[
          // 대중교통: overview ↔ step-by-step 두 단계
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _modeATransitNavStepMode
                ? _NavTransitCard(
                    navState: navState,
                    route: modeAState.routeResult!,
                    onOverview: () =>
                        setState(() => _modeATransitNavStepMode = false),
                  )
                : _ModeATransitNavOverviewCard(
                    navState: navState,
                    route: modeAState.routeResult!,
                    onStepMode: () =>
                        setState(() => _modeATransitNavStepMode = true),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ModeAWalkNavBottomStrip(
              navState: navState,
              transport: 'transit',
              totalDistanceM: modeAState.routeResult!.distanceKm * 1000,
              onStop: () {
                _cancelModeANav();
                _resetNavCamera();
              },
            ),
          ),
        ] else ...[
          // 도보/자전거: overview ↔ step-by-step 두 단계
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _modeANavStepMode
                ? _ModeAWalkNavTurnCard(
                    navState: navState,
                    transport: modeAState.routeResult!.transport,
                    turnPoint: _getModeACurrentTurn(),
                    distanceLabel: _getModeADistToNextTurnLabel(
                      modeAState.routeResult!.routePoints,
                    ),
                    onOverview: () => setState(() => _modeANavStepMode = false),
                  )
                : _ModeAWalkNavOverviewCard(
                    navState: navState,
                    destName: modeAState.to,
                    transport: modeAState.routeResult!.transport,
                    totalDistanceM: modeAState.routeResult!.distanceKm * 1000,
                    onStepMode: () => setState(() => _modeANavStepMode = true),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ModeAWalkNavBottomStrip(
              navState: navState,
              transport: modeAState.routeResult!.transport,
              totalDistanceM: modeAState.routeResult!.distanceKm * 1000,
              onStop: () {
                _cancelModeANav();
                _resetNavCamera();
              },
            ),
          ),
        ],
      ],

      // ── 검색 중 로딩 ─────────────────────────────────────────
      if (modeAState.isLoading)
        Positioned.fill(
          child: Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(
                color: kMapPrimary,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
    ];

    // 지도 포커스 모드: AnimatedOpacity로 UI 숨김 (폴리라인·마커는 Naver 레이어라 유지됨)
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: mapFocused,
          child: AnimatedOpacity(
            opacity: mapFocused ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(fit: StackFit.expand, children: children),
          ),
        ),
      ),
    ];
  }
}

// ── Mode A 방향 안내 핀 위젯 ────────────────────────────────────────────────

IconData _guideIconForType(int type, String guidance) {
  if (guidance.contains('횡단보도')) return Icons.transfer_within_a_station_rounded;
  return switch (type) {
    0 => Icons.trip_origin_rounded,
    12 => Icons.turn_right_rounded,
    13 => Icons.turn_left_rounded,
    14 => Icons.u_turn_left_rounded,
    100 => Icons.flag_rounded,
    _ => Icons.straight_rounded,
  };
}

class _ModeAGuidePin extends StatelessWidget {
  const _ModeAGuidePin({
    required this.type,
    required this.guidance,
    required this.color,
  });
  final int type;
  final String guidance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = _guideIconForType(type, guidance);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}
