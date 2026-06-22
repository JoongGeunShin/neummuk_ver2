part of '../map_overlay.dart';

/// 코스 생성 버튼의 기본 높이 (bottomPadding 제외) — 스크롤 패딩 계산용
const double _kGenerateBarHeight = 68.0;

// ── 공유 지오 헬퍼 (mode_b_mixin / mode_b_nav_mixin 공용) ──────────────────
//
// 두 가지 거리 계산을 의도적으로 분리한다:
//   • _preciseDistM  : Haversine — 구간 거리 합산 등 정밀 배치 계산
//   • _fastDistM     : Equirectangular — GPS 틱마다 호출되는 실시간 근접점 탐색
//                      (오차 ~0.1% 이내, 속도 우선)
//   • Geolocator.distanceBetween : 플랫폼 정밀 계산 — 단발성 이동 감지에만 사용

double _preciseDistM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  const toRad = pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _fastDistM(double lat1, double lng1, double lat2, double lng2) {
  const toRad = pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;
  final cosLat = cos(lat1 * toRad);
  return 6371000.0 * sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
}

double _bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  const toRad = pi / 180;
  final dLng = (lng2 - lng1) * toRad;
  final y = sin(dLng) * cos(lat2 * toRad);
  final x = cos(lat1 * toRad) * sin(lat2 * toRad) -
      sin(lat1 * toRad) * cos(lat2 * toRad) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

// ──────────────────────────────────────────────────────────────────────────────

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _modeBMarkerIcons;

  /// _ModeBNavOverlayMixin에서 구현 — 단계별 모드 활성 여부
  bool get _modeBNavStepMode;

  /// 생성 코스 구간별 도로 폴리라인 (인덱스 N = 이전 waypoint → waypoint[N])
  List<List<NLatLng>> _segmentPolylines = [];

  /// Bug 3: _drawGeneratedCourseOnMap 내 폴리라인 페치 진행 중 시 non-null (경쟁 방지용)
  Completer<void>? _segmentsFetchCompleter;

  /// 전체 경로 표시 여부 (false = 현재 구간만, true = 완료+현재+예정)
  bool _modeBShowAllSegments = false;

  // BottomSheet 내부 ScrollController (최소화 시 스크롤 리셋용)
  ScrollController? _sheetBScrollCtrl;
  bool _sheetBListenerAdded = false;

  // 네비게이션 폴리라인 실시간 트리밍 캐시
  NPolylineOverlay? _cachedNavRoutePolyline;
  final Map<int, NPolylineOverlay> _cachedNavSegPolylines = {};
  int _lastTrimGpxIdx = -1;
  int _lastTrimSegIdx = -1;
  bool _lastTrimOffRoute = false;

  // 검색된 스팟 목록 (마커 탭과 연결용)
  List<SpotEntity> _currentSearchedSpots = [];

  NaverMapController? get _ctrl;
  Position? get _position;

  // nav mixin에서 구현
  Future<void> _startModeBNavigation(TouristRouteEntity route, List<NLatLng> gpxPoints, {List<double> segmentDistancesM = const []});
  void _navigateToSpotFromWaypoint(SpotWaypoint wp);

  // ── 생성 코스 자동 재경로 ─────────────────────────────────────

  Future<void> _rerouteGeneratedCourse(
    Position p,
    TouristRouteEntity route,
    int currentWpIdx,
  ) async {
    if (!mounted || currentWpIdx >= route.waypoints.length) return;
    if (_segmentPolylines.isEmpty || currentWpIdx >= _segmentPolylines.length) return;

    try {
      final wp = route.waypoints[currentWpIdx];
      final newPts = await _fetchApproachRoute(
        fromLat: p.latitude,
        fromLng: p.longitude,
        toLat: wp.lat,
        toLng: wp.lng,
      );
      if (!mounted || newPts.length < 2) return;

      final userPos = NLatLng(p.latitude, p.longitude);
      final snapDist = Geolocator.distanceBetween(
        p.latitude, p.longitude,
        newPts.first.latitude, newPts.first.longitude,
      );
      _segmentPolylines[currentWpIdx] =
          snapDist > 10 ? [userPos, ...newPts] : newPts;

      await _drawSegmentsOnMap(currentWpIdx, showAll: _modeBShowAllSegments);

      // Bug 6: 재경로 후 nav provider의 구간 거리도 갱신
      final updatedDists = _segmentPolylines.map(_totalPolylineLength).toList();
      ref.read(modeBNavProvider.notifier).updateSegmentDistances(updatedDists);
    } catch (_) {}
  }

  // ── 전체 / 현재 구간 표시 토글 ────────────────────────────────────

  void _toggleShowAllSegments(int currentWpIdx) {
    if (!mounted) return;
    setState(() => _modeBShowAllSegments = !_modeBShowAllSegments); // 버튼 시각 갱신
    unawaited(_drawSegmentsOnMap(currentWpIdx, showAll: _modeBShowAllSegments));
  }

  // ── 구간별 도로 경로 일괄 페치 ────────────────────────────────────

  Future<void> _fetchAllSegmentPolylines({
    required double startLat,
    required double startLng,
    required List<SpotWaypoint> waypoints,
  }) async {
    final segments = <List<NLatLng>>[];
    double prevLat = startLat, prevLng = startLng;

    for (final wp in waypoints) {
      // _fetchApproachRoute: TMAP → Kakao 폴백 순서로 시도
      final pts = await _fetchApproachRoute(
        fromLat: prevLat,
        fromLng: prevLng,
        toLat: wp.lat,
        toLng: wp.lng,
      );
      if (pts.isNotEmpty) {
        final snapDist = Geolocator.distanceBetween(
            prevLat, prevLng, pts.first.latitude, pts.first.longitude);
        segments.add(snapDist > 10 ? [NLatLng(prevLat, prevLng), ...pts] : pts);
      } else {
        segments.add([NLatLng(prevLat, prevLng), NLatLng(wp.lat, wp.lng)]);
      }
      prevLat = wp.lat;
      prevLng = wp.lng;
    }
    _segmentPolylines = segments;
  }

  // ── 구간별 폴리라인 그리기 ────────────────────────────────────────

  Future<void> _drawSegmentsOnMap(int currentWpIdx, {bool showAll = false}) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted || _segmentPolylines.isEmpty) return;

    // context는 await 전에 캡처
    const completedColor = Color(0xFFBBBBBB);
    const upcomingColor = Color(0xFFB3E5FC);
    final accentColor = context.colors.accent;

    // 구간 교체 시 트리밍 캐시 무효화 (새 폴리라인 인스턴스로 교체되므로)
    _cachedNavSegPolylines.clear();
    _lastTrimSegIdx = -1;
    _lastTrimOffRoute = false;

    for (var i = 0; i < _segmentPolylines.length; i++) {
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'seg_$i'),
      ).catchError((_) {});
    }

    if (!mounted) return;

    if (showAll) {
      for (var i = 0; i < _segmentPolylines.length; i++) {
        final pts = _segmentPolylines[i];
        if (pts.length < 2) continue;
        final isCurrent = i == currentWpIdx;
        final isDone = i < currentWpIdx;

        final poly = NPolylineOverlay(
          id: 'seg_$i',
          coords: pts,
          color: isCurrent
              ? accentColor
              : (isDone
                  ? completedColor.withValues(alpha: 0.7)
                  : upcomingColor.withValues(alpha: 0.8)),
          width: isCurrent ? 5 : 3,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        );
        await ctrl.addOverlay(poly);
        // 현재 구간만 트리밍 캐시 저장
        if (isCurrent && mounted) _cachedNavSegPolylines[i] = poly;
      }
    } else {
      final idx = currentWpIdx.clamp(0, _segmentPolylines.length - 1);
      final pts = _segmentPolylines[idx];
      if (pts.length >= 2) {
        final poly = NPolylineOverlay(
          id: 'seg_$idx',
          coords: pts,
          color: accentColor,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        );
        await ctrl.addOverlay(poly);
        if (mounted) _cachedNavSegPolylines[idx] = poly;
      }
    }
  }

  void _disposeModeB() {
    if (_sheetBListenerAdded) {
      _sheetBCtrl.removeListener(_onSheetBSizeChanged);
    }
    _sheetBCtrl.dispose();
    _sheetBScrollCtrl = null;
    _clearNavPolylineCache();
  }

  void _onSheetBSizeChanged() {
    if (!_sheetBCtrl.isAttached) return;
    if (_sheetBCtrl.size <= 0.14) {
      // 최소화 시 내부 스크롤 리셋 → 다음 위로 드래그 시 sheet가 올라갈 수 있도록
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final sc = _sheetBScrollCtrl;
        if (sc != null && sc.hasClients && sc.offset > 0) {
          sc.jumpTo(0);
        }
      });
    }
  }

  void _expandSheetB() {
    if (_sheetBCtrl.isAttached) {
      _sheetBCtrl.animateTo(
        0.46,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearNavPolylineCache() {
    _cachedNavRoutePolyline = null;
    _cachedNavSegPolylines.clear();
    _lastTrimGpxIdx = -1;
    _lastTrimSegIdx = -1;
    _lastTrimOffRoute = false;
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
    final homeIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: const Color(0xFF4FC3F7), label: '⌂'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    _modeBMarkerIcons = {
      'walk': walkIcon,
      'bike': bikeIcon,
      'selected': selectedIcon,
      'spot': spotIcon,
      'home': homeIcon,
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

  /// 코스 미리보기 전용 마커: 순번 배지 + 출발지 홈 아이콘
  Future<void> _drawPreviewCourseMarkers(List<SpotWaypoint> waypoints) async {
    final ctrl = _ctrl;
    if (ctrl == null || waypoints.isEmpty) return;

    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;

    final isReturnCourse = waypoints.last.type == '출발지';
    var stepNum = 1;

    for (var i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final isOrigin = isReturnCourse && i == waypoints.length - 1;

      final NOverlayImage icon;
      final String captionText;
      final Color captionColor;

      if (isOrigin) {
        icon = icons['home'] ?? icons['spot']!;
        captionText = '⌂ 출발지';
        captionColor = const Color(0xFF4FC3F7);
      } else {
        icon = await NOverlayImage.fromWidget(
          widget: _StepNumberBadge(number: stepNum),
          size: const Size(32, 32),
          context: context,
        );
        captionText = '$stepNum. ${wp.name}';
        captionColor = const Color(0xFFFF6B6B);
        stepNum++;
      }

      if (!mounted) return;

      await ctrl.addOverlay(NMarker(
        id: 'prev_spot_$i',
        position: NLatLng(wp.lat, wp.lng),
        icon: icon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: 11,
          color: captionColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
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

    final isReturnCourse = waypoints.isNotEmpty && waypoints.last.type == '출발지';

    for (var i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final isCurrent = i == currentIdx;
      final isDone = i < currentIdx;
      final isOrigin = isReturnCourse && i == waypoints.length - 1;

      final NOverlayImage? icon;
      if (isCurrent) {
        icon = icons['selected'];
      } else if (isOrigin) {
        icon = icons['home']; // 출발지 귀환 마커
      } else {
        icon = icons['spot'];
      }

      final captionColor = isCurrent
          ? const Color(0xFFFFB547)
          : isOrigin
              ? const Color(0xFF4FC3F7)
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
      if (isDone && !isOrigin) marker.setAlpha(0.4);
      if (!isOrigin) {
        final tappedWp = wp;
        marker.setOnTapListener((_) => _navigateToSpotFromWaypoint(tappedWp));
      }
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
    final pos = _position;
    final double lat;
    final double lng;
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
    } else {
      final center = await _getMapCenter();
      lat = center.lat;
      lng = center.lng;
    }
    final cartItems = ref.read(cartProvider);
    await ref.read(routeSearchProvider.notifier).generateCourseFromSpots(
          food,
          lat: lat,
          lng: lng,
          cartItems: cartItems,
        );
  }

  Future<void> _drawGeneratedCourseOnMap(TouristRouteEntity course) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (!course.hasCoordinate || course.waypoints.isEmpty) return;

    // context는 첫 await 전에 캡처
    final accentColor = context.colors.accent;

    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);

    final originLat = _position?.latitude ?? course.startLat!;
    final originLng = _position?.longitude ?? course.startLng!;

    // 이미 동일 waypoint 수의 세그먼트가 있으면 API 재호출 생략
    final segmentsReady = _segmentPolylines.length == course.waypoints.length;

    setState(() => _gpxLoading = true);
    // Bug 3: 페치 시작 전 Completer 등록 (레이스 가드)
    final fetchCompleter = segmentsReady ? null : Completer<void>();
    if (fetchCompleter != null) _segmentsFetchCompleter = fetchCompleter;
    try {
      if (!segmentsReady) {
        await _fetchAllSegmentPolylines(
          startLat: originLat,
          startLng: originLng,
          waypoints: course.waypoints,
        );
        if (!fetchCompleter!.isCompleted) fetchCompleter.complete();
      }

      if (!mounted) return;

      // 처음 페치했을 때만 실제 도로 거리로 메트릭 보정 (재드로우 시 스킵)
      if (!segmentsReady && _segmentPolylines.isNotEmpty) {
        final roadDistM = _segmentPolylines.fold(
          0.0,
          (sum, seg) => sum + _totalPolylineLength(seg),
        );
        final roadDistKm = roadDistM / 1000;
        final isBike = course.type == '자전거';
        final speedKmh = isBike ? 15.0 : 4.0;
        final met = isBike
            ? AppConstants.metValues['bike']!
            : AppConstants.metValues['walk']!;
        final weightKg = ref.read(userProfileProvider).valueOrNull?.weightKg ??
            AppConstants.defaultWeightKg;
        final hours = roadDistKm / speedKmh;
        ref.read(routeSearchProvider.notifier).updateGeneratedCourseMetrics(
          distanceKm: double.parse(roadDistKm.toStringAsFixed(2)),
          durationMinutes: (hours * 60).round().clamp(1, 9999),
          kcal: (met * weightKg * hours).round(),
        );
      }

      // 탐색 미리보기: 구간별 폴리라인 개별 표시 (중복 구간 방향 인식용)
      final previewPts = <NLatLng>[];
      if (_segmentPolylines.isNotEmpty) {
        for (var i = 0; i < _segmentPolylines.length; i++) {
          final pts = _segmentPolylines[i];
          if (pts.length < 2) continue;
          previewPts.addAll(pts);
          await ctrl.addOverlay(NPolylineOverlay(
            id: 'seg_prev_$i',
            coords: pts,
            color: accentColor,
            width: 5,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          ));
        }
      }

      final drawCoords = previewPts.isNotEmpty
          ? previewPts
          : [NLatLng(originLat, originLng),
             ...course.waypoints.map((w) => NLatLng(w.lat, w.lng))];

      if (previewPts.isEmpty) {
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'seg_prev_0',
          coords: drawCoords,
          color: accentColor,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ));
      }

      await MapCameraUtils.fitPoints(ctrl, drawCoords, padding: const EdgeInsets.all(80));
    } catch (e) {
      if (fetchCompleter != null && !fetchCompleter.isCompleted) {
        fetchCompleter.completeError(e);
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _gpxLoading = false);
      if (fetchCompleter != null && _segmentsFetchCompleter == fetchCompleter) {
        _segmentsFetchCompleter = null;
      }
    }

    if (!mounted) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await _drawPreviewCourseMarkers(course.waypoints);
    if (!mounted) return;
    // 구간별 방향 화살표 (중복 구간에서도 진행 방향 명확히 표시)
    for (var i = 0; i < _segmentPolylines.length; i++) {
      if (!mounted) break;
      await _drawRouteArrows(_segmentPolylines[i], accentColor, 'prev_seg_$i');
    }
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

  // ── 카드 탭: 기성 코스 ────────────────────────────────────────

  Future<void> _onModeBCardTap(int idx, TouristRouteEntity route) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    // _loadModeBRouteGpx는 routeSearchProvider listener의 selectedRouteIdx 변경에서 처리
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
      // Bug 3: 미리보기 페치가 진행 중이면 완료 대기 (레이스 방지)
      final pendingFetch = _segmentsFetchCompleter;
      if (pendingFetch != null) {
        await pendingFetch.future.catchError((_) {});
      }

      // 구간별 폴리라인 페치 (아직 없으면) — 미리보기에서 이미 페치됐을 수도 있음
      if (_segmentPolylines.length != route.waypoints.length) {
        final startLat = pos?.latitude ?? route.startLat!;
        final startLng = pos?.longitude ?? route.startLng!;
        setState(() => _gpxLoading = true);
        try {
          // 기존 preview 폴리라인 제거 후 구간별로 교체
          await ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
          await _fetchAllSegmentPolylines(
            startLat: startLat,
            startLng: startLng,
            waypoints: route.waypoints,
          );
        } finally {
          if (mounted) setState(() => _gpxLoading = false);
        }
      } else {
        // 기존 generated_course 미리보기 폴리라인 제거 — seg_N으로 교체
        await ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      }

      // 내비게이션 시작: 전체 구간 표시 (완료=회색, 예정=회색, 현재=accent)
      if (mounted) {
        setState(() => _modeBShowAllSegments = true);
        await _drawSegmentsOnMap(0, showAll: true);
      }
      if (mounted) await _drawNavSpotMarkers(route.waypoints, currentIdx: 0);

      // 생성 코스: 현재 위치 → 첫 번째 스팟 접근 경로
      if (ctrl != null && pos != null && route.waypoints.isNotEmpty) {
        final firstWp = route.waypoints.first;
        final approachPoints = await _fetchApproachRoute(
          fromLat: pos.latitude, fromLng: pos.longitude,
          toLat: firstWp.lat, toLng: firstWp.lng,
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

    // 생성 코스: 도로 폴리라인 기반 구간 거리 계산 (nav 남은 거리 정확도 향상)
    final segDists = route.isGenerated &&
            _segmentPolylines.length == route.waypoints.length
        ? _segmentPolylines.map(_totalPolylineLength).toList()
        : <double>[];

    await _startModeBNavigation(route, gpxPoints,
        segmentDistancesM: segDists);
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

  double _distLL(NLatLng a, NLatLng b) =>
      _preciseDistM(a.latitude, a.longitude, b.latitude, b.longitude);

  double _bearingLL(NLatLng a, NLatLng b) =>
      _bearingDeg(a.latitude, a.longitude, b.latitude, b.longitude);

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
  }

  // ── 교차로 방향 마커 ───────────────────────────────────────────

  Future<void> _drawTurnMarkersOnMap(List<_TurnPoint> turns) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final ctx = context;

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      if (turn.type == _TurnType.straight || turn.type == _TurnType.arrival) continue;

      final icon = await NOverlayImage.fromWidget(
        widget: _TurnDirectionMarker(type: turn.type),
        size: const Size(28, 28),
        context: ctx,
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

  // ── 네비게이션 폴리라인 실시간 트리밍 ───────────────────────────
  // delete+add 대신 setCoords/setColor로 채널 메시지 최소화.
  // 인덱스·이탈 상태 변화가 없으면 호출 자체를 skip.

  Future<void> _trimNavPolylineToRemaining(
    Position p,
    ModeBNavState navState,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    final route = navState.route;
    if (route == null) return;
    final c = context.colors;
    const offRouteColor = Color(0xFFE67E22);

    if (!route.isGenerated && navState.gpxPoints.isNotEmpty) {
      if (_modeBNavStepMode) return;

      final startIdx = navState.nearestGpxPtIdx;
      final isOffRoute = navState.isOffRoute;

      // 인덱스도 이탈 상태도 바뀌지 않았으면 갱신 불필요
      if (startIdx == _lastTrimGpxIdx && isOffRoute == _lastTrimOffRoute) return;
      if (startIdx <= 0) return;

      final pts = navState.gpxPoints;
      if (startIdx >= pts.length - 1) return;

      final trimmed = pts
          .sublist(startIdx)
          .map((pt) => NLatLng(pt.lat, pt.lng))
          .toList();
      if (trimmed.length < 2) return;

      final polylineColor =
          isOffRoute ? offRouteColor : (route.type == '자전거' ? c.warn : c.primary);

      final cached = _cachedNavRoutePolyline;
      if (cached != null) {
        if (startIdx != _lastTrimGpxIdx) cached.setCoords(trimmed);
        if (isOffRoute != _lastTrimOffRoute) cached.setColor(polylineColor);
      } else {
        // 첫 호출: 기존 오버레이 교체 후 인스턴스 캐시
        await ctrl.deleteOverlay(
          NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'route_path'),
        ).catchError((_) {});
        if (!mounted) return;
        final poly = NPolylineOverlay(
          id: 'route_path',
          coords: trimmed,
          color: polylineColor,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        );
        await ctrl.addOverlay(poly);
        if (mounted) _cachedNavRoutePolyline = poly;
      }

      _lastTrimGpxIdx = startIdx;
      _lastTrimOffRoute = isOffRoute;

    } else if (route.isGenerated && _segmentPolylines.isNotEmpty) {
      if (_modeBNavStepMode) return;

      final currentIdx =
          navState.currentWaypointIdx.clamp(0, _segmentPolylines.length - 1);
      final pts = _segmentPolylines[currentIdx];
      if (pts.isEmpty) return;

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

      // 100m ≈ 위경도 0.001° → sq ≈ 0.000001 (경도 보정 없이 근사)
      final isOffRoute = nearestSqDist > 8.1e-7; // ~90m

      if (nearestIdx == _lastTrimSegIdx && isOffRoute == _lastTrimOffRoute) return;
      if (nearestIdx <= 0) return;
      if (nearestIdx >= pts.length - 1) return;

      final trimmed = pts.sublist(nearestIdx);
      if (trimmed.length < 2) return;

      final polylineColor = isOffRoute ? offRouteColor : c.accent;

      final cached = _cachedNavSegPolylines[currentIdx];
      if (cached != null) {
        if (nearestIdx != _lastTrimSegIdx) cached.setCoords(trimmed);
        if (isOffRoute != _lastTrimOffRoute) cached.setColor(polylineColor);
      } else {
        await ctrl.deleteOverlay(
          NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'seg_$currentIdx'),
        ).catchError((_) {});
        if (!mounted) return;
        final poly = NPolylineOverlay(
          id: 'seg_$currentIdx',
          coords: trimmed,
          color: polylineColor,
          width: 5,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        );
        await ctrl.addOverlay(poly);
        if (mounted) _cachedNavSegPolylines[currentIdx] = poly;
      }

      _lastTrimSegIdx = nearestIdx;
      _lastTrimOffRoute = isOffRoute;
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
      // Bottom panel + 코스 생성 버튼 (sheet 외부 고정)
      if (food != null) ...[
        DraggableScrollableSheet(
          controller: _sheetBCtrl,
          initialChildSize: 0.46,
          minChildSize: 0.13,
          maxChildSize: 0.80,
          snap: true,
          snapSizes: const [0.13, 0.46, 0.80],
          builder: (ctx, sc) {
            // scroll ctrl 저장 + listener 최초 1회 등록
            _sheetBScrollCtrl = sc;
            if (!_sheetBListenerAdded) {
              _sheetBListenerAdded = true;
              _sheetBCtrl.addListener(_onSheetBSizeChanged);
            }
            return _ModeBBottomPanel(
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
              onHandleTap: _expandSheetB,
              generateBarHeight: _kGenerateBarHeight,
            );
          },
        ),
        // 코스 생성 버튼 — sheet 크기와 무관하게 항상 화면 하단 고정
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _CourseGenerateBar(
            cartCount: cartCount,
            isGenerating: modeBState.isFetchingSpots,
            onGenerate: _onGenerateCourseFromSpots,
          ),
        ),
      ],
    ];
  }

  // ── 장바구니 바텀시트 ─────────────────────────────────────────

  void _showCartSheet(BuildContext context, List<SpotEntity> cartItems) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final items = ref.watch(cartProvider);
          final bottomPad = MediaQuery.paddingOf(ctx).bottom;
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
                  padding: EdgeInsets.fromLTRB(0, 32, 0, bottomPad + 32),
                  child: Text('아직 담은 스팟이 없어요',
                      style: TextStyle(color: c.textMuted, fontSize: 14)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
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
                ),
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

class _StepNumberBadge extends StatelessWidget {
  const _StepNumberBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
