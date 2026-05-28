part of '../map_overlay.dart';

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();

  // Abstract dependencies
  NaverMapController? get _ctrl;
  Position? get _position;

  void _disposeModeB() {
    _sheetBCtrl.dispose();
  }

  double _modeBTopBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;

  // ── Helpers ────────────────────────────────────────────────────

  Future<void> _updateModeBMarkers(List<TouristRouteEntity> routes) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
    for (final r in routes.where((r) => r.hasCoordinate)) {
      await ctrl.addOverlay(NMarker(
        id: r.id,
        position: NLatLng(r.startLat!, r.startLng!),
      ));
    }
  }

  Future<void> _onModeBSearch() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final pos = _position;
    await ref.read(routeSearchProvider.notifier).loadRoutes(
          food,
          lat: pos?.latitude ?? 37.5635,
          lng: pos?.longitude ?? 126.9869,
        );
  }

  Future<void> _selectModeBRoute(int idx) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    final routes = ref.read(routeSearchProvider).routes;
    if (idx >= routes.length) return;
    final route = routes[idx];
    final ctrl = _ctrl;
    if (ctrl == null) return;

    if (route.hasCoordinate) {
      await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
      await ctrl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(route.startLat!, route.startLng!),
          zoom: 14,
        ),
      );
      if (route.hasImages && mounted) {
        _showImageGallery(context, route);
      }
    } else {
      await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
      if (route.gpxpath == null) return;
      setState(() => _gpxLoading = true);
      try {
        final points = await _fetchGpxPoints(route.gpxpath!);
        if (!mounted || points.length < 2) return;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'route_path',
          coords: points,
          color: const Color(0xFF03C75A),
          width: 5,
        ));
        await MapCameraUtils.fitPoints(ctrl, points);
      } finally {
        if (mounted) setState(() => _gpxLoading = false);
      }
    }
  }

  Future<List<NLatLng>> _fetchGpxPoints(String gpxUrl) async {
    try {
      final res = await http
          .get(Uri.parse(gpxUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = res.body;
      final pattern =
          RegExp(r'<(?:trkpt|rtept)\s[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"');
      final patternAlt =
          RegExp(r'<(?:trkpt|rtept)\s[^>]*lon="([^"]+)"[^>]*lat="([^"]+)"');
      final points = <NLatLng>[];
      for (final m in pattern.allMatches(body)) {
        final lat = double.tryParse(m.group(1) ?? '');
        final lng = double.tryParse(m.group(2) ?? '');
        if (lat != null && lng != null) points.add(NLatLng(lat, lng));
      }
      if (points.isEmpty) {
        for (final m in patternAlt.allMatches(body)) {
          final lng = double.tryParse(m.group(1) ?? '');
          final lat = double.tryParse(m.group(2) ?? '');
          if (lat != null && lng != null) points.add(NLatLng(lat, lng));
        }
      }
      if (points.length > 500) {
        final step = points.length ~/ 500;
        return [for (int i = 0; i < points.length; i += step) points[i]];
      }
      return points;
    } catch (e) {
      debugPrint('[GPX] $e url=$gpxUrl');
      return [];
    }
  }

  // ── Mode B overlay widgets ─────────────────────────────────────

  List<Widget> _buildModeBOverlays(
    BuildContext context,
    MapMode mode,
    FoodEntity? food,
    RouteSearchState modeBState,
    double bottomPad,
    bool locating,
  ) {
    if (mode != MapMode.modeB) return const [];
    return [
      // Top bar
      if (food != null)
        Positioned(
          top: 0, left: 0, right: 0,
          child: _ModeBTopBar(food: food, onBack: () => context.pop()),
        ),
      // GPX loading chip
      if (_gpxLoading)
        Positioned(
          top: _modeBTopBarHeight(context) + 12,
          left: 0, right: 0,
          child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
        ),
      // Bottom panel sheet
      if (food != null)
        DraggableScrollableSheet(
          controller: _sheetBCtrl,
          initialChildSize: 0.46,
          minChildSize: 0.13,
          maxChildSize: 0.80,
          snap: true,
          snapSizes: const [0.13, 0.46, 0.80],
          builder: (ctx, sc) => _ModeBBottomPanel(
            scrollController: sc,
            state: modeBState,
            food: food,
            pos: _position,
            isLocating: locating,
            onSearch: _onModeBSearch,
            onTransportChange: (v) {
              final notifier = ref.read(routeSearchProvider.notifier);
              notifier.setTransport(
                v, food,
                lat: _position?.latitude ?? 37.5635,
                lng: _position?.longitude ?? 126.9869,
              );
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onSelectRoute: _selectModeBRoute,
            onStartTap: () => context.go('/record'),
          ),
        ),
    ];
  }
}
