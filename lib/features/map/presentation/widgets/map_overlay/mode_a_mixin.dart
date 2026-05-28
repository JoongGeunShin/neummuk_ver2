part of '../map_overlay.dart';

mixin _ModeAOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode A state ───────────────────────────────────────────────
  bool _sheetAExpanded = false;
  Map<String, NOverlayImage>? _routeMarkerIcons;

  // Abstract dependencies
  NaverMapController? get _ctrl;
  Position? get _position;
  bool get _locating;
  set _locating(bool value);
  Future<void> _drawTransitStepMarkers(RouteResultEntity result, int activeIdx);
  Future<void> _resetNavCamera();

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
      setState(() => _sheetAExpanded = false);
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

  // ── Mode A overlay widgets ─────────────────────────────────────

  List<Widget> _buildModeAOverlays(
    BuildContext context,
    MapMode mode,
    ModeAState modeAState,
    ModeANavState navState,
    double bottomPad,
  ) {
    if (mode != MapMode.modeA) return const [];
    return [
      // Route input panel (top)
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
          onBack: () => context.pop(),
        ),
      ),
      // Kcal widget (top-right)
      Positioned(
        right: 12,
        top: MediaQuery.paddingOf(context).top + 220,
        child: _KcalWidget(routeKcal: modeAState.routeResult?.kcalBurn),
      ),
      // Result sheet (bottom, not during navigation)
      if (modeAState.routeResult != null && !navState.isNavigating)
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: _sheetAExpanded
                ? context.screenHeight * 0.82
                : context.screenHeight * 0.52,
            decoration: const BoxDecoration(
              color: kMapPanel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, -12)),
              ],
            ),
            child: _ModeAResultSheet(
              state: modeAState,
              expanded: _sheetAExpanded,
              onToggleExpand: () =>
                  setState(() => _sheetAExpanded = !_sheetAExpanded),
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
            ),
          ),
        ),
      // Navigation cards (during navigation)
      if (navState.isNavigating) ...[
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12, right: 12,
          child: modeAState.routeResult!.transport == 'transit'
              ? _NavTransitCard(navState: navState, route: modeAState.routeResult!)
              : _NavTopCard(navState: navState, route: modeAState.routeResult!),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _NavBottomStrip(
            navState: navState,
            route: modeAState.routeResult!,
            onStop: () {
              ref.read(modeANavProvider.notifier).stop();
              _resetNavCamera();
            },
          ),
        ),
      ],
      // Loading overlay
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
  }
}
