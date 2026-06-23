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
  bool _modeAMapFocus = false;    // 지도 탭 시 UI 숨김
  bool _routePanelEditing = false; // 경로 수정 패널 열림 여부

  void _disposeModeA() {
    _sheetACtrl.dispose();
    _nearbyIconCache.clear();
  }

  // Abstract dependencies
  NaverMapController? get _ctrl;
  Position? get _position;
  bool get _locating;
  set _locating(bool value);
  Future<void> _drawTransitStepMarkers(RouteResultEntity result, int activeIdx);
  Future<void> _resetNavCamera();
  _TurnPoint? _getModeACurrentTurn();
  String _getModeADistToNextTurnLabel(List<LatLng> pts);

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
    _routeMarkerIcons = {'origin': originIcon, 'dest': destIcon, 'waypoint': wpIcon};
    return _routeMarkerIcons!;
  }

  Future<void> _syncModeAMarkers(ModeAState s) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = context.colors;
    const ids = ['wp_origin', 'wp_dest', 'wp_0', 'wp_1', 'wp_2'];
    for (final id in ids) {
      try {
        await ctrl.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id));
      } catch (_) {}
    }
    final icons = await _getRouteMarkerIcons();
    if (!mounted) return;
    if (s.originLat != null && s.originLng != null) {
      await ctrl.addOverlay(NMarker(
        id: 'wp_origin',
        position: NLatLng(s.originLat!, s.originLng!),
        icon: icons['origin'],
        caption: NOverlayCaption(
          text: s.from, textSize: 11,
          color: c.success, haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      ));
    }
    if (s.destLat != null && s.destLng != null) {
      await ctrl.addOverlay(NMarker(
        id: 'wp_dest',
        position: NLatLng(s.destLat!, s.destLng!),
        icon: icons['dest'],
        caption: NOverlayCaption(
          text: s.to, textSize: 11,
          color: c.danger, haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      ));
    }
    for (var i = 0; i < s.waypoints.length; i++) {
      final wp = s.waypoints[i];
      await ctrl.addOverlay(NMarker(
        id: 'wp_$i',
        position: NLatLng(wp.latitude, wp.longitude),
        icon: icons['waypoint'],
        caption: NOverlayCaption(
          text: wp.name, textSize: 11,
          color: c.accent, haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      ));
    }
  }

  Future<void> _drawModeAPolyline(RouteResultEntity? result) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = context.colors;

    // 이전 대중교통 구간 폴리라인 제거
    for (var i = 0; i < _transitSegPolylineCount; i++) {
      ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'transit_seg_$i'),
      ).catchError((_) {});
    }
    _transitSegPolylineCount = 0;

    // 이전 화살표·방향 마커 제거
    await _clearModeADecorations();

    await ctrl.deleteOverlay(
      const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'mode_a_route'),
    ).catchError((_) {});
    if (result == null || result.routePoints.isEmpty) return;

    final coords = result.routePoints
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();

    if (result.transport == 'transit') {
      // 구간별 별색 폴리라인: 도보=c.success(초록), 버스·지하철=c.pinUser(파랑)
      final stepsWithPts = result.transitSteps
          .where((s) => s.stepPoints.length >= 2)
          .toList();
      if (stepsWithPts.isNotEmpty) {
        var segIdx = 0;
        for (final step in stepsWithPts) {
          final segCoords = step.stepPoints
              .map((p) => NLatLng(p.latitude, p.longitude))
              .toList();
          await ctrl.addOverlay(NPolylineOverlay(
            id: 'transit_seg_$segIdx',
            coords: segCoords,
            color: step.isWalk ? c.success : c.pinUser,
            width: step.isWalk ? 4 : 6,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          ));
          // 도보 구간에만 방향 화살표 (버스·지철은 빠르게 지나가 생략)
          if (step.isWalk) {
            await _drawModeARouteArrows(segCoords, c.success);
          }
          segIdx++;
        }
        _transitSegPolylineCount = segIdx;
      } else {
        // stepPoints 없는 폴백: 단색 폴리라인
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'mode_a_route',
          coords: coords,
          color: c.pinUser,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ));
        await _drawModeARouteArrows(coords, c.pinUser);
      }
      if (result.transitSteps.isNotEmpty) {
        await _drawTransitStepMarkers(result, 0);
      }
    } else {
      final color = switch (result.transport) {
        'walk' => c.primary,
        'bike' => c.warn,
        _      => c.primary,
      };
      await ctrl.addOverlay(NPolylineOverlay(
        id: 'mode_a_route',
        coords: coords,
        color: color,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      ));
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
  }

  // ── Mode A 지오 헬퍼 (mode_b_mixin과 독립) ─────────────────────────

  static double _modeADistM(NLatLng a, NLatLng b) {
    const r = 6371000.0;
    const toRad = pi / 180;
    final dLat = (b.latitude - a.latitude) * toRad;
    final dLng = (b.longitude - a.longitude) * toRad;
    final aa = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * toRad) * cos(b.latitude * toRad) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(aa), sqrt(1 - aa));
  }

  static double _modeABearing(NLatLng a, NLatLng b) {
    const toRad = pi / 180;
    final dLng = (b.longitude - a.longitude) * toRad;
    final y = sin(dLng) * cos(b.latitude * toRad);
    final x = cos(a.latitude * toRad) * sin(b.latitude * toRad) -
        sin(a.latitude * toRad) * cos(b.latitude * toRad) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double _modeATotalLen(List<NLatLng> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += _modeADistM(pts[i - 1], pts[i]);
    }
    return total;
  }

  static ({NLatLng pos, double bearing})? _modeAPointAtDist(
      List<NLatLng> pts, double dist) {
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final seg = _modeADistM(pts[i - 1], pts[i]);
      if (acc + seg >= dist) {
        final t = (dist - acc) / seg;
        final lat = pts[i - 1].latitude + t * (pts[i].latitude - pts[i - 1].latitude);
        final lng = pts[i - 1].longitude + t * (pts[i].longitude - pts[i - 1].longitude);
        return (pos: NLatLng(lat, lng), bearing: _modeABearing(pts[i - 1], pts[i]));
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
      ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: 'mode_a_arrow_$i'),
      ).catchError((_) {});
    }
    _modeAArrowCount = 0;
    for (var i = 0; i < _modeAGuideMarkerCount; i++) {
      ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: 'mode_a_guide_$i'),
      ).catchError((_) {});
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

      await ctrl.addOverlay(NMarker(
        id: 'mode_a_arrow_$idx',
        position: result.pos,
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
      idx++;
    }
    _modeAArrowCount = idx;
  }

  // ── 교차로 방향 마커 (Kakao 안내 포인트 기반) ─────────────────────

  Future<void> _drawModeAGuideMarkers(List<RouteGuide> guides, String transport) async {
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
            type: guide.type, guidance: guide.guidance, color: accentColor),
        size: const Size(28, 28),
        context: context,
      );
      if (!mounted) break;

      await ctrl.addOverlay(NMarker(
        id: 'mode_a_guide_$idx',
        position: NLatLng(guide.latitude, guide.longitude),
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
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
      ref.read(modeAProvider.notifier).setOriginGps(
            pos.latitude, pos.longitude, '현재 위치');
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
          ref.read(modeAProvider.notifier).setOriginGps(
                latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onSetDest: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setDestCoords(
                latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onAddWaypoint: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: locationName,
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              ));
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

  void _showRerouteDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('경로를 벗어났어요',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          '현재 경로에서 60m 이상 벗어났습니다.\n계속 진행하시겠어요?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(modeANavProvider.notifier).stop();
            },
            child: const Text('안내 종료',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(modeANavProvider.notifier).dismissReroute();
            },
            child: const Text('계속 진행',
                style: TextStyle(
                    color: kMapGreen, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showArrivalMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kMapGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('목적지에 도착했어요!',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
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
          ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: candidate.name,
                latitude: candidate.latitude,
                longitude: candidate.longitude,
              ));
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
            NOverlayInfo(type: NOverlayType.marker, id: 'nearby_$i'));
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
              pos: NLatLng(s.restaurants[i].latitude, s.restaurants[i].longitude),
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
                    s.nearbyDurunubi[i].startLng!),
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
              pos: NLatLng(s.nearbyPlaces[i].latitude, s.nearbyPlaces[i].longitude),
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
    final showRoutePanel = !navState.isNavigating &&
        (modeAState.routeResult == null || _routePanelEditing);

    // 안내 중에는 지도 포커스(UI 숨김) 비활성
    final mapFocused = _modeAMapFocus && !navState.isNavigating;

    final children = <Widget>[
      // ── 경로 입력 패널 ──────────────────────────────────────
      if (showRoutePanel)
        Positioned(
          top: 0, left: 0, right: 0,
          child: _ModeARoutePanel(
            state: modeAState,
            locating: _locating,
            onTapOrigin: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Row(children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('출발지를 설정해주세요',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                duration: const Duration(seconds: 2),
                backgroundColor: kMapPanel,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              ));
              ref.read(mapModeProvider.notifier).set(MapMode.explore);
            },
            onGpsOrigin: _fetchGpsOriginForModeA,
            onTapDest: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Row(children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('도착지를 설정해주세요',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                duration: const Duration(seconds: 2),
                backgroundColor: kMapPanel,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              ));
              ref.read(mapModeProvider.notifier).set(MapMode.explore);
            },
            onClearDest: () =>
                ref.read(modeAProvider.notifier).setDestCoords(null, null, ''),
            onSetTransport: (t) => ref.read(modeAProvider.notifier).setTransport(t),
            onRemoveWaypoint: (i) => ref.read(modeAProvider.notifier).removeWaypoint(i),
            onReorderWaypoints: (o, n) =>
                ref.read(modeAProvider.notifier).reorderWaypoint(o, n),
            onSearch: (modeAState.originLat == null || modeAState.to.isEmpty)
                ? null
                : _onModeASearch,
            onResetAll: () {
              ref.read(modeAProvider.notifier).clearAll();
              _fetchGpsOriginForModeA();
            },
            onBack: () => context.pop(),
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
                  BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: _kWhite87),
                  SizedBox(width: 6),
                  Text('경로 수정',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _kWhite87)),
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
          child: _KcalWidget(routeKcal: modeAState.routeResult?.kcalBurn),
        ),

      // ── 결과 시트 (안내 중 아닐 때) ──────────────────────────
      if (modeAState.routeResult != null && !navState.isNavigating)
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
              ref.read(modeANavProvider.notifier).start(modeAState.routeResult!);
            },
            onLoadCandidates: (extra) =>
                ref.read(modeAProvider.notifier).loadWaypointCandidates(extra),
            onAddWaypointCandidate: (candidate) {
              ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: candidate.name,
                latitude: candidate.latitude,
                longitude: candidate.longitude,
              ));
              _showWaypointCandidateSheet(context);
            },
            onSwitchTab: (tab) =>
                ref.read(modeAProvider.notifier).switchNearbyTab(tab),
            onPlaceTap: (place) => context.push('/place-detail', extra: place),
            onDurunubiTap: (course) => context.push('/place-detail', extra: course),
          ),
        ),

      // ── 안내 중: 상단 카드 + 하단 스트립 ──────────────────────
      if (navState.isNavigating) ...[
        if (modeAState.routeResult!.transport == 'transit') ...[
          // 대중교통: 기존 카드 유지
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _NavTransitCard(
                  navState: navState, route: modeAState.routeResult!),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _NavBottomStrip(
              navState: navState,
              route: modeAState.routeResult!,
              currentGuideIdx: 0,
              totalGuides: 0,
              onPrevGuide: () {},
              onNextGuide: () {},
              onStop: () {
                ref.read(modeANavProvider.notifier).stop();
                _resetNavCamera();
              },
            ),
          ),
        ] else ...[
          // 도보/자전거: Mode B 스타일 방향 전환 안내 카드
          Positioned(
            top: 0, left: 0, right: 0,
            child: _ModeAWalkNavTopCard(
              navState: navState,
              transport: modeAState.routeResult!.transport,
              turnPoint: _getModeACurrentTurn(),
              distanceLabel: _getModeADistToNextTurnLabel(
                  modeAState.routeResult!.routePoints),
              onClose: () {
                ref.read(modeANavProvider.notifier).stop();
                _resetNavCamera();
              },
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _ModeAWalkNavBottomStrip(
              navState: navState,
              transport: modeAState.routeResult!.transport,
              onStop: () {
                ref.read(modeANavProvider.notifier).stop();
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
              child: CircularProgressIndicator(color: kMapGreen, strokeWidth: 2),
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
