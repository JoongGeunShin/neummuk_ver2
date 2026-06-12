part of '../map_overlay.dart';

mixin _ModeAOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode A state ───────────────────────────────────────────────
  final _sheetACtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _routeMarkerIcons;
  final Map<int, NOverlayImage> _nearbyIconCache = {};
  int _nearbyMarkerCount = 0;
  bool _modeAMapFocus = false;    // 지도 탭 시 UI 숨김
  bool _routePanelEditing = false; // 경로 수정 패널 열림 여부
  int _navGuidePageIdx = 0;        // 현재 보여지는 안내 스텝 인덱스

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
  Future<void> _panToGuidePoint(int idx, RouteResultEntity route);

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
    final originIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFF2ECC71), label: 'A'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final destIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFE74C3C), label: 'B'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final wpIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFF39C12), label: '●'),
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
          color: const Color(0xFF2ECC71), haloColor: Colors.black87,
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
          color: const Color(0xFFE74C3C), haloColor: Colors.black87,
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
          color: const Color(0xFFF39C12), haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      ));
    }
  }

  Future<void> _drawModeAPolyline(RouteResultEntity? result) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.deleteOverlay(
      const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'mode_a_route'),
    ).catchError((_) {});
    if (result == null || result.routePoints.isEmpty) return;

    final coords = result.routePoints
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();

    final color = switch (result.transport) {
      'walk'    => const Color(0xFF03C75A),
      'bike'    => const Color(0xFFFFB547),
      'transit' => const Color(0xFF7C8AFF),
      _         => const Color(0xFF03C75A),
    };

    await ctrl.addOverlay(NPolylineOverlay(
      id: 'mode_a_route',
      coords: coords,
      color: color,
      width: 5,
      lineCap: NLineCap.round,
      lineJoin: NLineJoin.round,
    ));

    if (result.transport == 'transit' && result.transitSteps.isNotEmpty) {
      await _drawTransitStepMarkers(result, 0);
    }

    if (mounted) {
      await MapCameraUtils.fitPoints(
        ctrl,
        coords,
        padding: const EdgeInsets.fromLTRB(60, 180, 60, 320),
      );
    }
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

  // ── Nearby item action ────────────────────────────────────────

  void _showNearbyItemActionSheet({
    required String name,
    required double lat,
    required double lng,
    String? category,
    required Object item,
  }) {
    final canAddWaypoint =
        ref.read(modeAProvider).waypoints.length < 3;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NearbyItemActionSheet(
        name: name,
        category: category,
        canAddWaypoint: canAddWaypoint,
        onSetDest: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setDestCoords(lat, lng, name);
          ref.read(modeAProvider.notifier).search();
          setState(() => _routePanelEditing = false);
        },
        onAddWaypoint: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).addWaypoint(
                RouteWaypoint(name: name, latitude: lat, longitude: lng));
          ref.read(modeAProvider.notifier).search();
        },
        onViewDetail: () {
          Navigator.pop(context);
          context.push('/place-detail', extra: item);
        },
      ),
    );
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

    final Color markerColor;
    final List<({String id, NLatLng pos, String name, Object item})> pins;

    switch (s.nearbyTab) {
      case ModeANearbyTab.restaurant:
        markerColor = kMapGreen;
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
        markerColor = const Color(0xFF7C8AFF);
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
        markerColor = const Color(0xFFFFB547);
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
        if (captured is RestaurantEntity) {
          _showNearbyItemActionSheet(
            name: captured.name,
            lat: captured.latitude,
            lng: captured.longitude,
            category: captured.category,
            item: captured,
          );
        } else if (captured is PlaceEntity) {
          _showNearbyItemActionSheet(
            name: captured.name,
            lat: captured.latitude,
            lng: captured.longitude,
            category: captured.category,
            item: captured,
          );
        } else if (captured is TouristRouteEntity) {
          _showNearbyItemActionSheet(
            name: captured.name,
            lat: captured.startLat ?? 0,
            lng: captured.startLng ?? 0,
            category: captured.region != null
                ? '두루누비 · ${captured.region}'
                : '두루누비',
            item: captured,
          );
        }
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
            onTap: () => setState(() => _routePanelEditing = true),
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
            onRestaurantTap: (r) => _showNearbyItemActionSheet(
              name: r.name,
              lat: r.latitude,
              lng: r.longitude,
              category: r.category,
              item: r,
            ),
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
            onPlaceTap: (place) => _showNearbyItemActionSheet(
              name: place.name,
              lat: place.latitude,
              lng: place.longitude,
              category: place.category,
              item: place,
            ),
            onDurunubiTap: (course) => _showNearbyItemActionSheet(
              name: course.name,
              lat: course.startLat ?? 0,
              lng: course.startLng ?? 0,
              category: course.region != null
                  ? '두루누비 · ${course.region}'
                  : '두루누비',
              item: course,
            ),
          ),
        ),

      // ── 안내 중: 상단 캐러셀 카드 + 하단 스트립 ─────────────────
      if (navState.isNavigating) ...[
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 0, right: 0,
          child: modeAState.routeResult!.transport == 'transit'
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _NavTransitCard(
                      navState: navState, route: modeAState.routeResult!),
                )
              : _NavGuideCarousel(
                  guides: modeAState.routeResult!.guides,
                  activeIdx: _navGuidePageIdx
                      .clamp(0, (modeAState.routeResult!.guides.length - 1).clamp(0, 999)),
                  route: modeAState.routeResult!,
                  onPageChanged: (idx) {
                    setState(() => _navGuidePageIdx = idx);
                    final route = modeAState.routeResult!;
                    if (idx < route.guides.length) {
                      _panToGuidePoint(idx, route);
                    }
                  },
                  onClose: () {
                    ref.read(modeANavProvider.notifier).stop();
                    _resetNavCamera();
                  },
                ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _NavBottomStrip(
            navState: navState,
            route: modeAState.routeResult!,
            currentGuideIdx: _navGuidePageIdx,
            totalGuides: modeAState.routeResult!.guides.length,
            onPrevGuide: () {
              if (_navGuidePageIdx > 0) {
                setState(() => _navGuidePageIdx--);
                _panToGuidePoint(_navGuidePageIdx, modeAState.routeResult!);
              }
            },
            onNextGuide: () {
              final guides = modeAState.routeResult!.guides;
              if (_navGuidePageIdx < guides.length - 1) {
                setState(() => _navGuidePageIdx++);
                _panToGuidePoint(_navGuidePageIdx, modeAState.routeResult!);
              }
            },
            onStop: () {
              ref.read(modeANavProvider.notifier).stop();
              _resetNavCamera();
            },
          ),
        ),
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
