part of '../map_overlay.dart';

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _modeBMarkerIcons;

  // Abstract dependencies
  NaverMapController? get _ctrl;
  Position? get _position;

  void _disposeModeB() {
    _sheetBCtrl.dispose();
  }

  double _modeBTopBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;

  // ── Helpers ────────────────────────────────────────────────────

  Future<Map<String, NOverlayImage>> _getModeBMarkerIcons() async {
    if (_modeBMarkerIcons != null) return _modeBMarkerIcons!;
    final walkIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFF03C75A), label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final bikeIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFFFB547), label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final selectedIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFFFD700), label: '★'),
      size: const Size(32, 32),
      context: context,
    );
    if (!mounted) return {};
    _modeBMarkerIcons = {'walk': walkIcon, 'bike': bikeIcon, 'selected': selectedIcon};
    return _modeBMarkerIcons!;
  }

  Future<void> _updateModeBMarkers(
    List<TouristRouteEntity> routes, {
    int selectedIdx = -1,
  }) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);

    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;

    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      if (!r.hasCoordinate) continue;
      final isSelected = i == selectedIdx;
      final icon = isSelected
          ? icons['selected']
          : (r.type == '자전거' ? icons['bike'] : icons['walk']);

      await ctrl.addOverlay(NMarker(
        id: 'route_$i',
        position: NLatLng(r.startLat!, r.startLng!),
        icon: icon,
        caption: NOverlayCaption(
          text: r.name,
          textSize: 11,
          color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF03C75A),
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
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

  // 카드 탭: 루트 선택(GPX) + 상세 페이지
  Future<void> _onModeBCardTap(int idx, TouristRouteEntity route) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    await _loadModeBRouteGpx(idx);
    if (mounted) context.push('/place-detail', extra: route);
  }

  Future<void> _loadModeBRouteGpx(int idx) async {
    final routes = ref.read(routeSearchProvider).routes;
    if (idx >= routes.length) return;
    final route = routes[idx];
    final ctrl = _ctrl;
    if (ctrl == null) return;

    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);

    if (route.hasCoordinate) {
      await ctrl.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(route.startLat!, route.startLng!),
        zoom: 14,
      ));
    }

    if (route.gpxpath != null) {
      setState(() => _gpxLoading = true);
      try {
        final points = await _fetchGpxPoints(route.gpxpath!);
        if (!mounted || points.length < 2) return;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'route_path',
          coords: points,
          color: route.type == '자전거'
              ? const Color(0xFFFFB547)
              : const Color(0xFF03C75A),
          width: 5,
        ));
        await MapCameraUtils.fitPoints(ctrl, points);
      } finally {
        if (mounted) setState(() => _gpxLoading = false);
      }
    }

    await _updateModeBMarkers(routes, selectedIdx: idx);
  }

  Future<void> _onStartModeBCourse(TouristRouteEntity route) async {
    final ctrl = _ctrl;
    final pos = _position;

    if (_sheetBCtrl.isAttached) {
      _sheetBCtrl.animateTo(
        0.13,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    if (ctrl != null && route.hasCoordinate && pos != null) {
      final approachPoints = await _fetchApproachRoute(
        fromLat: pos.latitude, fromLng: pos.longitude,
        toLat: route.startLat!, toLng: route.startLng!,
      );
      if (mounted && approachPoints.isNotEmpty) {
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'approach_path',
          coords: approachPoints,
          color: const Color(0xFF7C8AFF),
          width: 4,
        ));
        final allPoints = [
          NLatLng(pos.latitude, pos.longitude),
          ...approachPoints,
          NLatLng(route.startLat!, route.startLng!),
        ];
        await MapCameraUtils.fitPoints(ctrl, allPoints,
            padding: const EdgeInsets.all(80));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${route.name} 코스를 시작합니다!\n걷기가 자동으로 기록됩니다 🏃',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF03C75A),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<List<NLatLng>> _fetchApproachRoute({
    required double fromLat, required double fromLng,
    required double toLat, required double toLng,
  }) async {
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return [];
      final uri = Uri.parse('${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'KakaoAK $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin': {'x': fromLng, 'y': fromLat},
          'destination': {'x': toLng, 'y': toLat},
          'waypoints': [],
          'priority': 'RECOMMEND',
          'road_details': false,
        }),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];
      final r = routes[0] as Map<String, dynamic>;
      if ((r['result_code'] as int? ?? -1) != 0) return [];
      final points = <NLatLng>[];
      for (final section in (r['sections'] as List? ?? [])) {
        for (final road in ((section as Map)['roads'] as List? ?? [])) {
          final vx = (road as Map)['vertexes'] as List? ?? [];
          for (var i = 0; i < vx.length - 1; i += 2) {
            points.add(NLatLng(
              (vx[i + 1] as num).toDouble(),
              (vx[i] as num).toDouble(),
            ));
          }
        }
      }
      return points;
    } catch (e) {
      debugPrint('[ModeBApproach] $e');
      return [];
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
            onLoadMore: () => ref.read(routeSearchProvider.notifier).loadMore(),
            onTransportChange: (v) {
              final notifier = ref.read(routeSearchProvider.notifier);
              notifier.setTransport(
                v, food,
                lat: _position?.latitude ?? 37.5635,
                lng: _position?.longitude ?? 126.9869,
              );
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onCardTap: _onModeBCardTap,
          ),
        ),
    ];
  }
}
