part of '../map_overlay.dart';

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _modeBMarkerIcons;

  NaverMapController? get _ctrl;
  Position? get _position;

  // nav mixin에서 구현
  Future<void> _startModeBNavigation(TouristRouteEntity route, List<NLatLng> gpxPoints);

  void _disposeModeB() {
    _sheetBCtrl.dispose();
  }

  double _modeBTopBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;

  // ── 마커 아이콘 ────────────────────────────────────────────────

  Future<Map<String, NOverlayImage>> _getModeBMarkerIcons() async {
    if (_modeBMarkerIcons != null) return _modeBMarkerIcons!;
    final c = context.colors;
    final walkIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.primary, label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final bikeIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.warn, label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final selectedIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.accent, label: '★'),
      size: const Size(32, 32),
      context: context,
    );
    if (!mounted) return {};
    final spotIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: const Color(0xFFFF6B6B), label: '◆'),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return {};
    _modeBMarkerIcons = {
      'walk': walkIcon,
      'bike': bikeIcon,
      'selected': selectedIcon,
      'spot': spotIcon,
    };
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
    final c = context.colors;

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
          color: isSelected ? c.accent : c.primary,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      ));

      // 생성된 코스의 경유지 스팟 마커
      if (isSelected && r.isGenerated) {
        await _drawSpotWaypointMarkers(r.waypoints, icons['spot']);
      }
    }
  }

  Future<void> _drawSpotWaypointMarkers(
    List<SpotWaypoint> waypoints,
    NOverlayImage? icon,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (var i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      await ctrl.addOverlay(NMarker(
        id: 'spot_wp_$i',
        position: NLatLng(wp.lat, wp.lng),
        icon: icon,
        caption: NOverlayCaption(
          text: wp.name,
          textSize: 10,
          color: const Color(0xFFFF6B6B),
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      ));
    }
  }

  /// 네비게이션 중 스팟 마커 표시
  /// - currentIdx 이전: 방문 완료 (흐린 색)
  /// - currentIdx: 현재 목적지 (강조, 별 아이콘)
  /// - currentIdx 이후: 미방문 (일반 색)
  Future<void> _drawNavSpotMarkers(
    List<SpotWaypoint> waypoints, {
    required int currentIdx,
  }) async {
    final ctrl = _ctrl;
    if (ctrl == null || waypoints.isEmpty) return;

    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;

    for (var i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final isCurrent = i == currentIdx;
      final isDone = i < currentIdx;

      final icon = isCurrent ? icons['selected'] : icons['spot'];
      final captionColor = isCurrent
          ? const Color(0xFFFFB547)
          : isDone
              ? Colors.white30
              : const Color(0xFFFF6B6B);
      final captionText = isCurrent ? '📍 ${wp.name}' : wp.name;

      final marker = NMarker(
        id: 'nav_spot_$i',
        position: NLatLng(wp.lat, wp.lng),
        icon: icon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: isCurrent ? 12 : 10,
          color: captionColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: !isCurrent,
      );
      if (isDone) marker.setAlpha(0.4);
      await ctrl.addOverlay(marker);
    }
  }

  // ── 맵 중심점 좌표 가져오기 ───────────────────────────────────

  Future<({double lat, double lng})> _getMapCenter() async {
    if (_ctrl != null) {
      final cam = await _ctrl!.getCameraPosition();
      return (lat: cam.target.latitude, lng: cam.target.longitude);
    }
    return (
      lat: _position?.latitude ?? 37.5635,
      lng: _position?.longitude ?? 126.9869,
    );
  }

  // ── 기성 코스 검색 (항상 맵 중심점 기준) ─────────────────────

  Future<void> _onModeBSearch() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final center = await _getMapCenter();
    await ref.read(routeSearchProvider.notifier).loadRoutes(
          food,
          lat: center.lat,
          lng: center.lng,
        );
  }

  // ── 스팟 기반 코스 생성 (맵 중심점 기준) ─────────────────────

  Future<void> _onGenerateCourseFromSpots() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final center = await _getMapCenter();
    await ref.read(routeSearchProvider.notifier).generateCourseFromSpots(
          food,
          lat: center.lat,
          lng: center.lng,
        );
    // ref.listen이 generatedCourse 변경을 감지해서 자동으로 지도에 표시
  }

  Future<void> _drawGeneratedCourseOnMap(TouristRouteEntity course) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (!course.hasCoordinate || course.waypoints.isEmpty) return;

    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);

    final startLat = course.startLat!;
    final startLng = course.startLng!;

    // Kakao Mobility로 도로 경로 조회 (실패 시 직선으로 fallback)
    setState(() => _gpxLoading = true);
    try {
      final roadPoints = await _fetchRoadRouteForGeneratedCourse(
        startLat: startLat,
        startLng: startLng,
        waypoints: course.waypoints,
      );

      if (!mounted) return;
      final c = context.colors;

      final drawCoords = roadPoints.isNotEmpty
          ? roadPoints
          : <NLatLng>[
              NLatLng(startLat, startLng),
              ...course.waypoints.map((w) => NLatLng(w.lat, w.lng)),
            ];

      await ctrl.addOverlay(NPolylineOverlay(
        id: 'generated_course',
        coords: drawCoords,
        color: c.accent,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      ));

      await MapCameraUtils.fitPoints(ctrl, drawCoords, padding: const EdgeInsets.all(80));
    } finally {
      if (mounted) setState(() => _gpxLoading = false);
    }

    // 스팟 마커 표시 (polyline 그린 후 별도로 그려야 지워지지 않음)
    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await _drawSpotWaypointMarkers(course.waypoints, icons['spot']);
  }

  // ── 생성 코스 도로 경로 (Kakao Mobility waypoints) ─────────────

  Future<List<NLatLng>> _fetchRoadRouteForGeneratedCourse({
    required double startLat,
    required double startLng,
    required List<SpotWaypoint> waypoints,
  }) async {
    if (waypoints.isEmpty) return [];
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return [];

      final intermediates = waypoints.length > 1
          ? waypoints
              .sublist(0, waypoints.length - 1)
              .map((w) => {'name': w.name, 'x': w.lng, 'y': w.lat})
              .toList()
          : <Map<String, dynamic>>[];

      final uri = Uri.parse('${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions');
      final res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'KakaoAK $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'origin': {'x': startLng, 'y': startLat},
              'destination': {'x': waypoints.last.lng, 'y': waypoints.last.lat},
              'waypoints': intermediates,
              'priority': 'RECOMMEND',
              'road_details': false,
            }),
          )
          .timeout(const Duration(seconds: 10));

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
      debugPrint('[ModeBRoadRoute] $e');
      return [];
    }
  }

  // ── 카드 탭: 기성 코스 ────────────────────────────────────────

  Future<void> _onModeBCardTap(int idx, TouristRouteEntity route) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    // GPX 로드는 백그라운드로, place-detail은 즉시 이동
    unawaited(_loadModeBRouteGpx(idx));
    if (mounted) context.push('/place-detail', extra: route);
  }

  // ── 생성 코스 탭: 별도 경로 ───────────────────────────────────

  Future<void> _onGeneratedCourseTap(TouristRouteEntity course) async {
    ref.read(routeSearchProvider.notifier).selectGeneratedCourse();
    await _drawGeneratedCourseOnMap(course);
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

    if (route.isGenerated) {
      await _drawGeneratedCourseOnMap(route);
      return;
    }

    if (route.gpxpath != null) {
      setState(() => _gpxLoading = true);
      try {
        final points = await _fetchGpxPoints(route.gpxpath!);
        if (!mounted || points.length < 2) return;
        final c = context.colors;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'route_path',
          coords: points,
          color: route.type == '자전거' ? c.warn : c.primary,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ));
        await MapCameraUtils.fitPoints(ctrl, points);
      } finally {
        if (mounted) setState(() => _gpxLoading = false);
      }
    }

    await _updateModeBMarkers(routes, selectedIdx: idx);
  }

  // ── 안내 시작 ──────────────────────────────────────────────────

  Future<void> _onStartModeBCourse(TouristRouteEntity route) async {
    final ctrl = _ctrl;
    final pos = _position;

    // 시트 접기
    if (_sheetBCtrl.isAttached) {
      _sheetBCtrl.animateTo(0.13,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    // 마커 정리 (polyline은 아직 건드리지 않음)
    await ctrl?.clearOverlays(type: NOverlayType.marker);

    List<NLatLng> gpxPoints = [];

    if (route.isGenerated) {
      // 생성된 코스: 기존 도로경로 polyline 유지, 접근선 없이 바로 시작
      // (자동차 경로 API로 접근선을 그리면 도보 경로와 달라 혼란스러움)
      await _drawNavSpotMarkers(route.waypoints, currentIdx: 0);
    } else {
      // 기성 코스: GPX 경로 + 접근 경로
      if (route.gpxpath != null) {
        setState(() => _gpxLoading = true);
        try {
          gpxPoints = await _fetchGpxPoints(route.gpxpath!);
        } finally {
          if (mounted) setState(() => _gpxLoading = false);
        }
      }

      if (ctrl != null && route.hasCoordinate && pos != null) {
        final approachPoints = await _fetchApproachRoute(
          fromLat: pos.latitude, fromLng: pos.longitude,
          toLat: route.startLat!, toLng: route.startLng!,
        );
        if (mounted && approachPoints.isNotEmpty) {
          final c = context.colors;
          await ctrl.addOverlay(NPolylineOverlay(
            id: 'approach_path',
            coords: approachPoints,
            color: c.pinUser,
            width: 4,
          ));
        }
      }
    }

    // 네비게이션 시작
    await _startModeBNavigation(route, gpxPoints);
  }

  // ── 맵 중심 재검색 (동일 로직 사용) ──────────────────────────

  Future<void> _onModeBSearchFromMapCenter() => _onModeBSearch();

  // ── 접근 경로 (Kakao Mobility) ─────────────────────────────────

  Future<List<NLatLng>> _fetchApproachRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return [];
      final uri = Uri.parse('${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions');
      final res = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 10));
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

  // ── GPX 파싱 ──────────────────────────────────────────────────

  Future<List<NLatLng>> _fetchGpxPoints(String gpxUrl) async {
    try {
      final res =
          await http.get(Uri.parse(gpxUrl)).timeout(const Duration(seconds: 15));
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

    // 앱 재시작 복원 시 food가 null이어도 nav 상태의 음식명으로 topbar 표시
    final navState = ref.read(modeBNavProvider);
    final showNavTopBar = food == null &&
        navState.isNavigating &&
        navState.foodName.isNotEmpty;

    return [
      // Top bar
      if (food != null)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ModeBTopBar(food: food, onBack: () => context.pop()),
        )
      else if (showNavTopBar)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ModeBNavRestoreTopBar(
            foodName: navState.foodName,
            foodKcal: navState.foodKcal,
            onBack: () => context.pop(),
          ),
        ),
      // GPX 로딩 칩
      if (_gpxLoading)
        Positioned(
          top: _modeBTopBarHeight(context) + 12,
          left: 0,
          right: 0,
          child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
        ),
      // Bottom panel
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
            onSearchFromCenter: _onModeBSearchFromMapCenter,
            onLoadMore: () => ref.read(routeSearchProvider.notifier).loadMore(),
            onTransportChange: (v) {
              final notifier = ref.read(routeSearchProvider.notifier);
              notifier.setTransport(v, food,
                  lat: _position?.latitude ?? 37.5635,
                  lng: _position?.longitude ?? 126.9869);
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onCardTap: _onModeBCardTap,
            onStartNav: _onStartModeBCourse,
            onTagToggle: (tag) =>
                ref.read(routeSearchProvider.notifier).toggleTag(tag),
            onGenerateCourse: _onGenerateCourseFromSpots,
            onGeneratedCourseTap: _onGeneratedCourseTap,
          ),
        ),
    ];
  }
}
