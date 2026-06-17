part of '../map_overlay.dart';

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _modeBMarkerIcons;

  /// _ModeBNavOverlayMixin에서 구현 — 단계별 모드 활성 여부
  bool get _modeBNavStepMode;

  // 경로 화살표 마커 추적
  final _arrowCounts = <String, int>{};
  List<NLatLng> _lastGeneratedRoutePoints = [];

  // 네비게이션 중 폴리라인 트리밍 스로틀
  DateTime? _lastPolylineTrim;

  // 검색된 스팟 목록 (마커 탭과 연결용)
  List<SpotEntity> _currentSearchedSpots = [];

  NaverMapController? get _ctrl;
  Position? get _position;

  // nav mixin에서 구현
  Future<void> _startModeBNavigation(TouristRouteEntity route, List<NLatLng> gpxPoints);

  // ── 생성 코스 자동 재경로 ─────────────────────────────────────

  Future<void> _rerouteGeneratedCourse(
    Position p,
    TouristRouteEntity route,
    int currentWpIdx,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final remaining = route.waypoints.sublist(currentWpIdx);
    if (remaining.isEmpty) return;
    try {
      final newPoints = await _fetchRoadRouteForGeneratedCourse(
        startLat: p.latitude,
        startLng: p.longitude,
        waypoints: remaining,
      );
      if (!mounted || newPoints.length < 2) return;
      final userPos = NLatLng(p.latitude, p.longitude);
      final snapDist = Geolocator.distanceBetween(
        p.latitude, p.longitude,
        newPoints.first.latitude, newPoints.first.longitude,
      );
      _lastGeneratedRoutePoints =
          snapDist > 10 ? [userPos, ...newPoints] : newPoints;
      final c = context.colors;
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'generated_course'),
      ).catchError((_) {});
      if (!mounted) return;
      await ctrl.addOverlay(NPolylineOverlay(
        id: 'generated_course',
        coords: newPoints,
        color: c.accent,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      ));
    } catch (_) {}
  }

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

  // ── 검색된 스팟 마커 (탭 핸들러 포함) ───────────────────────────

  Future<void> _drawSearchedSpotMarkers(List<SpotEntity> spots) async {
    _currentSearchedSpots = spots;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);

    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;

    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final marker = NMarker(
        id: 'search_spot_$i',
        position: NLatLng(spot.lat, spot.lng),
        icon: icons['spot'],
        caption: NOverlayCaption(
          text: spot.name,
          textSize: 11,
          color: const Color(0xFFFF6B6B),
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      );
      final capturedSpot = spot;
      final capturedIdx = i;
      marker.setOnTapListener((_) {
        ref.read(routeSearchProvider.notifier).selectSpot(capturedIdx);
        _onSpotTap(capturedSpot);
      });
      await ctrl.addOverlay(marker);
    }

    // 스팟들이 보이도록 카메라 조정
    if (spots.isNotEmpty) {
      final coords = spots.map((s) => NLatLng(s.lat, s.lng)).toList();
      if (coords.length == 1) {
        await ctrl.updateCamera(NCameraUpdate.scrollAndZoomTo(
          target: coords.first, zoom: 15,
        ));
      } else {
        await MapCameraUtils.fitPoints(ctrl, coords, padding: const EdgeInsets.all(80));
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

  // ── 스팟 태그 탭 ──────────────────────────────────────────────

  Future<void> _onSpotTagTap(SpotTag tag) async {
    final notifier = ref.read(routeSearchProvider.notifier);
    final currentTag = ref.read(routeSearchProvider).activeSpotTag;

    if (currentTag == tag) {
      // 같은 태그 재탭 → 해제 + 마커 제거
      notifier.selectSpotTag(tag);
      _currentSearchedSpots = [];
      await _ctrl?.clearOverlays(type: NOverlayType.marker);
      await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      return;
    }

    // 새 태그 선택
    notifier.selectSpotTag(tag);
    final center = await _getMapCenter();
    await notifier.searchSpotsForActiveTag(lat: center.lat, lng: center.lng);
    // ref.listen이 searchedSpots 변경을 감지 → _drawSearchedSpotMarkers 자동 호출
  }

  // ── "주변 코스" 탭 ────────────────────────────────────────────

  Future<void> _onNearbyCourseTap() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final notifier = ref.read(routeSearchProvider.notifier);
    final isActive = ref.read(routeSearchProvider).nearbyCoursesActive;

    if (isActive) {
      // 이미 활성 → 해제
      notifier.toggleNearbyCourses();
      _currentSearchedSpots = [];
      await _ctrl?.clearOverlays(type: NOverlayType.marker);
      await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      return;
    }

    notifier.toggleNearbyCourses();
    final center = await _getMapCenter();
    await notifier.loadRoutes(food, lat: center.lat, lng: center.lng);
  }

  // ── 스팟 탭 → 상세 페이지 ────────────────────────────────────

  void _onSpotTap(SpotEntity spot) {
    if (!mounted) return;
    context.push('/spot-detail', extra: spot);
  }

  // ── 스팟 기반 코스 생성 ───────────────────────────────────────

  Future<void> _onGenerateCourseFromSpots() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final center = await _getMapCenter();
    final cartItems = ref.read(cartProvider);
    await ref.read(routeSearchProvider.notifier).generateCourseFromSpots(
          food,
          lat: center.lat,
          lng: center.lng,
          cartItems: cartItems,
        );
  }

  Future<void> _drawGeneratedCourseOnMap(TouristRouteEntity course) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (!course.hasCoordinate || course.waypoints.isEmpty) return;

    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);

    final courseStartLat = course.startLat!;
    final courseStartLng = course.startLng!;
    final originLat = _position?.latitude ?? courseStartLat;
    final originLng = _position?.longitude ?? courseStartLng;

    setState(() => _gpxLoading = true);
    try {
      final roadPoints = await _fetchRoadRouteForGeneratedCourse(
        startLat: originLat,
        startLng: originLng,
        waypoints: course.waypoints,
      );

      if (!mounted) return;
      final c = context.colors;

      final List<NLatLng> drawCoords;
      if (roadPoints.isNotEmpty) {
        final userPos = NLatLng(originLat, originLng);
        final snapDist = Geolocator.distanceBetween(
          originLat, originLng,
          roadPoints.first.latitude, roadPoints.first.longitude,
        );
        drawCoords = snapDist > 10 ? [userPos, ...roadPoints] : roadPoints;
      } else {
        drawCoords = [
          NLatLng(originLat, originLng),
          ...course.waypoints.map((w) => NLatLng(w.lat, w.lng)),
        ];
      }

      _lastGeneratedRoutePoints = drawCoords;

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

    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await _drawSpotWaypointMarkers(course.waypoints, icons['spot']);
    if (!mounted) return;
    await _drawRouteArrows(_lastGeneratedRoutePoints, context.colors.accent, 'gen');
  }

  // ── 도보 경로 (TMAP Pedestrian) ──────────────────────────────

  Future<List<NLatLng>> _fetchPedestrianRoute({
    required double startLat,
    required double startLng,
    required List<({double lat, double lng})> waypointCoords,
  }) async {
    if (waypointCoords.isEmpty) return [];
    try {
      final key = dotenv.env['TMAP_APP_KEY'] ?? '';
      if (key.isEmpty) return [];

      final destination = waypointCoords.last;
      final intermediates = waypointCoords.length > 1
          ? waypointCoords.sublist(0, waypointCoords.length - 1)
          : <({double lat, double lng})>[];

      final bodyParts = [
        'startX=$startLng',
        'startY=$startLat',
        'endX=${destination.lng}',
        'endY=${destination.lat}',
        'startName=${Uri.encodeComponent('출발')}',
        'endName=${Uri.encodeComponent('도착')}',
        'reqCoordType=WGS84GEO',
        'resCoordType=WGS84GEO',
        'searchOption=0',
      ];
      if (intermediates.isNotEmpty) {
        const maxPass = 5;
        final capped = intermediates.length <= maxPass
            ? intermediates
            : List.generate(
                maxPass,
                (i) => intermediates[
                  (i * (intermediates.length - 1) ~/ (maxPass - 1))
                      .clamp(0, intermediates.length - 1)
                ],
              );
        bodyParts.add(
          'passList=${capped.map((w) => '${w.lng},${w.lat}').join('_')}',
        );
      }
      final bodyStr = bodyParts.join('&');
      debugPrint('[TMAP] body=$bodyStr');

      final res = await http
          .post(
            Uri.parse(
              'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
            ),
            headers: {
              'appKey': key,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('[TMAP] status=${res.statusCode} body=${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        return [];
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('[TMAP] features=${(data['features'] as List?)?.length}');
      final features = data['features'] as List?;
      if (features == null) return [];

      final points = <NLatLng>[];
      for (final feature in features) {
        final geometry = (feature as Map)['geometry'] as Map?;
        if (geometry == null || geometry['type'] != 'LineString') continue;
        final coords = geometry['coordinates'] as List?;
        if (coords == null) continue;
        for (final c in coords) {
          points.add(NLatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ));
        }
      }
      debugPrint('[TMAP] points=${points.length}');
      return points;
    } catch (e) {
      debugPrint('[TMAP] error=$e');
      return [];
    }
  }

  // ── 생성 코스 도로 경로 (OSRM 우선 → Kakao Mobility fallback) ──

  Future<List<NLatLng>> _fetchRoadRouteForGeneratedCourse({
    required double startLat,
    required double startLng,
    required List<SpotWaypoint> waypoints,
  }) async {
    if (waypoints.isEmpty) return [];

    final pedestrianPts = await _fetchPedestrianRoute(
      startLat: startLat,
      startLng: startLng,
      waypointCoords: waypoints.map((w) => (lat: w.lat, lng: w.lng)).toList(),
    );
    if (pedestrianPts.isNotEmpty) return pedestrianPts;

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
    unawaited(_loadModeBRouteGpx(idx));
    if (mounted) context.push('/place-detail', extra: route);
  }

  // ── 생성 코스 탭 ─────────────────────────────────────────────

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
        final routeColor = route.type == '자전거' ? c.warn : c.primary;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'route_path',
          coords: points,
          color: routeColor,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ));
        await MapCameraUtils.fitPoints(ctrl, points);
        if (mounted) await _drawRouteArrows(points, routeColor, 'gpx');
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

    if (_sheetBCtrl.isAttached) {
      _sheetBCtrl.animateTo(0.13,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    await ctrl?.clearOverlays(type: NOverlayType.marker);

    List<NLatLng> gpxPoints = [];

    if (route.isGenerated) {
      await _drawNavSpotMarkers(route.waypoints, currentIdx: 0);
      if (mounted && _lastGeneratedRoutePoints.isNotEmpty) {
        await _drawRouteArrows(
            _lastGeneratedRoutePoints, context.colors.accent, 'gen');
      }
    } else {
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

    await _startModeBNavigation(route, gpxPoints);
  }

  // ── 접근 경로 (OSRM 우선 → Kakao Mobility fallback) ────────────

  Future<List<NLatLng>> _fetchApproachRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final pedestrianPts = await _fetchPedestrianRoute(
      startLat: fromLat,
      startLng: fromLng,
      waypointCoords: [(lat: toLat, lng: toLng)],
    );
    if (pedestrianPts.isNotEmpty) {
      final snapDist = Geolocator.distanceBetween(
        fromLat, fromLng,
        pedestrianPts.first.latitude, pedestrianPts.first.longitude,
      );
      return snapDist > 10
          ? [NLatLng(fromLat, fromLng), ...pedestrianPts]
          : pedestrianPts;
    }

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

  // ── 경로 방향 화살표 ───────────────────────────────────────────

  double _distLL(NLatLng a, NLatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _bearingLL(NLatLng a, NLatLng b) {
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _totalPolylineLength(List<NLatLng> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += _distLL(pts[i - 1], pts[i]);
    }
    return total;
  }

  ({NLatLng pos, double bearing})? _pointAtDistance(
      List<NLatLng> pts, double dist) {
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final seg = _distLL(pts[i - 1], pts[i]);
      if (acc + seg >= dist) {
        final t = (dist - acc) / seg;
        final lat = pts[i - 1].latitude +
            t * (pts[i].latitude - pts[i - 1].latitude);
        final lng = pts[i - 1].longitude +
            t * (pts[i].longitude - pts[i - 1].longitude);
        return (pos: NLatLng(lat, lng), bearing: _bearingLL(pts[i - 1], pts[i]));
      }
      acc += seg;
    }
    return null;
  }

  Future<void> _drawRouteArrows(
    List<NLatLng> points,
    Color color,
    String idPrefix,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || points.length < 2 || !mounted) return;

    final totalLen = _totalPolylineLength(points);
    if (totalLen < 100) return;

    final count = (totalLen / 100).clamp(4.0, 25.0).round();
    final spacing = totalLen / (count + 1);

    var arrowIdx = 0;
    for (var n = 1; n <= count; n++) {
      final result = _pointAtDistance(points, spacing * n);
      if (result == null) continue;
      if (!mounted) break;

      final icon = await NOverlayImage.fromWidget(
        widget: _RouteArrowIcon(bearingDeg: result.bearing, color: color),
        size: const Size(16, 16),
        context: context,
      );
      if (!mounted) break;

      await ctrl.addOverlay(NMarker(
        id: '${idPrefix}_arrow_$arrowIdx',
        position: result.pos,
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
      arrowIdx++;
    }
    _arrowCounts[idPrefix] = arrowIdx;
  }

  // ── 교차로 방향 마커 ───────────────────────────────────────────

  Future<void> _drawTurnMarkersOnMap(List<_TurnPoint> turns) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      if (turn.type == _TurnType.straight || turn.type == _TurnType.arrival) continue;

      final icon = await NOverlayImage.fromWidget(
        widget: _TurnDirectionMarker(type: turn.type),
        size: const Size(28, 28),
        context: context,
      );
      if (!mounted) break;

      await ctrl.addOverlay(NMarker(
        id: 'turn_$i',
        position: NLatLng(turn.lat, turn.lng),
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
    }
  }

  // ── 네비게이션 폴리라인 점진적 트리밍 ────────────────────────────

  Future<void> _trimNavPolylineToRemaining(
    Position p,
    ModeBNavState navState,
  ) async {
    final now = DateTime.now();
    if (_lastPolylineTrim != null &&
        now.difference(_lastPolylineTrim!).inSeconds < 3) {
      return;
    }

    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    final route = navState.route;
    if (route == null) return;

    late List<NLatLng> trimmed;
    late String polylineId;
    late Color polylineColor;
    final c = context.colors;

    if (!route.isGenerated && navState.gpxPoints.isNotEmpty) {
      if (_modeBNavStepMode) return;

      final startIdx = navState.nearestGpxPtIdx;
      if (startIdx <= 0) return;
      final pts = navState.gpxPoints;
      if (startIdx >= pts.length - 1) return;
      trimmed = pts.sublist(startIdx)
          .map((pt) => NLatLng(pt.lat, pt.lng))
          .toList();
      polylineId = 'route_path';
      polylineColor = route.type == '자전거' ? c.warn : c.primary;
    } else if (route.isGenerated && _lastGeneratedRoutePoints.isNotEmpty) {
      if (_modeBNavStepMode) return;

      final pts = _lastGeneratedRoutePoints;
      int nearestIdx = 0;
      double nearestSqDist = double.infinity;
      for (int i = 0; i < pts.length; i++) {
        final dlat = pts[i].latitude - p.latitude;
        final dlng = pts[i].longitude - p.longitude;
        final sq = dlat * dlat + dlng * dlng;
        if (sq < nearestSqDist) {
          nearestSqDist = sq;
          nearestIdx = i;
        }
      }
      if (nearestIdx <= 0) return;
      if (nearestIdx >= pts.length - 1) return;
      trimmed = pts.sublist(nearestIdx);
      polylineId = 'generated_course';
      polylineColor = c.accent;
    } else {
      return;
    }

    if (trimmed.length < 2) return;

    _lastPolylineTrim = now;

    await ctrl.deleteOverlay(
      NOverlayInfo(type: NOverlayType.polylineOverlay, id: polylineId),
    ).catchError((_) {});
    if (!mounted) return;

    await ctrl.addOverlay(NPolylineOverlay(
      id: polylineId,
      coords: trimmed,
      color: polylineColor,
      width: 5,
      lineCap: NLineCap.round,
      lineJoin: NLineJoin.round,
    ));
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

    final navState = ref.read(modeBNavProvider);
    final showNavTopBar = food == null &&
        navState.isNavigating &&
        navState.foodName.isNotEmpty;

    final walkKcal = ref.watch(walkSessionProvider).caloriesKcal;
    final cartItems = ref.watch(cartProvider);
    final cartCount = cartItems.length;

    return [
      // Top bar
      if (food != null)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeBTopBar(food: food, onBack: () => context.pop()),
              _ModeBKcalMiniBar(
                todayKcal: walkKcal,
                targetKcal: food.kcal,
              ),
            ],
          ),
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
          top: _modeBTopBarHeight(context) + 44,
          left: 0,
          right: 0,
          child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
        ),
      // 장바구니 FAB (탐색 중, 네비게이션 아닐 때)
      if (food != null)
        AnimatedBuilder(
          animation: _sheetBCtrl,
          builder: (ctx, child) {
            final screenH = MediaQuery.sizeOf(ctx).height;
            final sheetH = _sheetBCtrl.isAttached
                ? _sheetBCtrl.size * screenH
                : screenH * 0.46;
            return Positioned(left: 16, bottom: sheetH + 16, child: child!);
          },
          child: _CartFab(
            count: cartCount,
            onTap: () => _showCartSheet(context, cartItems),
          ),
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
            cartCount: cartCount,
            isLocating: locating,
            onLoadMore: () => ref.read(routeSearchProvider.notifier).loadMore(),
            onTransportChange: (v) {
              final notifier = ref.read(routeSearchProvider.notifier);
              notifier.setTransport(v, food,
                  lat: _position?.latitude ?? 37.5635,
                  lng: _position?.longitude ?? 126.9869);
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onSpotTagTap: _onSpotTagTap,
            onNearbyCourseTap: _onNearbyCourseTap,
            onSpotItemTap: (idx, spot) {
              ref.read(routeSearchProvider.notifier).selectSpot(idx);
              _onSpotTap(spot);
            },
            onCardTap: _onModeBCardTap,
            onStartNav: _onStartModeBCourse,
            onGeneratedCourseTap: _onGeneratedCourseTap,
            onGenerateCourse: _onGenerateCourseFromSpots,
          ),
        ),
    ];
  }

  // ── 장바구니 바텀시트 ─────────────────────────────────────────

  void _showCartSheet(BuildContext context, List<SpotEntity> cartItems) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final items = ref.watch(cartProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: c.outline, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('코스 장바구니',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.primarySoft, borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length}개',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.primary)),
                    ),
                    const Spacer(),
                    if (items.isNotEmpty)
                      GestureDetector(
                        onTap: () => ref.read(cartProvider.notifier).clear(),
                        child: Text('전체 삭제',
                            style: TextStyle(
                                fontSize: 12,
                                color: c.textMuted,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('아직 담은 스팟이 없어요',
                      style: TextStyle(color: c.textMuted, fontSize: 14)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(color: c.outline, height: 1),
                  itemBuilder: (_, i) {
                    final spot = items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt, borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(_spotTypeEmoji(spot.type), style: const TextStyle(fontSize: 18))),
                      ),
                      title: Text(spot.name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                      subtitle: spot.address != null
                          ? Text(spot.address!, style: TextStyle(fontSize: 11, color: c.textMuted))
                          : null,
                      trailing: GestureDetector(
                        onTap: () => ref.read(cartProvider.notifier).remove(spot.id),
                        child: Icon(Icons.remove_circle_outline_rounded, color: c.textMuted, size: 20),
                      ),
                    );
                  },
                ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          );
        },
      ),
    );
  }

  String _spotTypeEmoji(String type) {
    switch (type) {
      case 'tourist_sight': return '🏛️';
      case 'culture': return '🎭';
      case 'event': return '🎉';
      case 'sports': return '⛹️';
      case 'shopping': return '🛍️';
      default: return '📍';
    }
  }
}
