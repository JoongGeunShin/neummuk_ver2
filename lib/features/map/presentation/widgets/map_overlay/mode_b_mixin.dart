part of '../map_overlay.dart';

/// 코스 생성 버튼의 기본 높이 (bottomPadding 제외) — 스크롤 패딩 계산용
const double _kGenerateBarHeight = 68.0;

// ── 공유 지오 헬퍼 (mode_b_mixin / mode_b_nav_mixin 공용) ──────────────────
//
// 두 가지 거리 계산을 의도적으로 분리한다 (core/utils/geo_utils.dart 위임):
//   • _preciseDistM  : Haversine — 구간 거리 합산 등 정밀 배치 계산
//   • _fastDistM     : Equirectangular — GPS 틱마다 호출되는 실시간 근접점 탐색
//                      (오차 ~0.1% 이내, 속도 우선)
//   • Geolocator.distanceBetween : 플랫폼 정밀 계산 — 단발성 이동 감지에만 사용

double _preciseDistM(double lat1, double lng1, double lat2, double lng2) =>
    haversineDistanceM(lat1, lng1, lat2, lng2);

double _fastDistM(double lat1, double lng1, double lat2, double lng2) =>
    fastDistanceM(lat1, lng1, lat2, lng2);

double _bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  const toRad = pi / 180;
  final dLng = (lng2 - lng1) * toRad;
  final y = sin(dLng) * cos(lat2 * toRad);
  final x = cos(lat1 * toRad) * sin(lat2 * toRad) -
      sin(lat1 * toRad) * cos(lat2 * toRad) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// 턴 마커의 지도 오버레이 ID — 구간+구간 내 인덱스로 결정되는 내용 기반 ID라서
/// 리스트 순서가 바뀌어도(지나간 턴 제거 등) 항상 같은 턴을 가리킨다.
String _turnMarkerId(_TurnPoint t) => 'turn_${t.segIdx}_${t.gpxIdx}';

/// 스팟 타입 → 대표 이모지 (마커/리스트 공용)
String _spotTypeEmoji(String type) => switch (type) {
      'tourist_sight' => '🏛️',
      'culture' => '🎭',
      'event' => '🎉',
      'sports' => '⛹️',
      'shopping' => '🛍️',
      _ => '📍',
    };

// ──────────────────────────────────────────────────────────────────────────────

mixin _ModeBOverlayMixin on ConsumerState<MapOverlay> {
  // ── Mode B state ───────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();
  Map<String, NOverlayImage>? _modeBMarkerIcons;

  /// _ModeBNavOverlayMixin에서 구현 — 단계별 모드 활성 여부
  bool get _modeBNavStepMode;

  /// _ModeBNavOverlayMixin에서 구현 — 방향 전환 포인트 목록 (재경로 시 갱신 필요)
  List<_TurnPoint> get _modeBTurnPoints;
  set _modeBTurnPoints(List<_TurnPoint> value);

  /// _ModeBNavOverlayMixin에서 구현 — 지도에 표시되는 코스 전체 턴 마커 목록
  List<_TurnPoint> get _allRouteTurnMarkers;
  set _allRouteTurnMarkers(List<_TurnPoint> value);

  /// _ModeBNavOverlayMixin에서 구현 — 도로 경로 포인트 → 턴포인트 계산
  List<_TurnPoint> _computeTurnPoints(List<({double lat, double lng})> pts, {int segIdx});

  /// _ModeBNavOverlayMixin에서 구현 — 현재 구간 도로 경로상의 위치 인덱스
  set _modeBRoadNearestPtIdx(int value);

  /// _ModeBNavOverlayMixin에서 구현 — 이번 GPS 틱의 도로 스냅 기준 진행률 캐시
  /// (폴리라인 트리밍이 provider와 동일한 최근접점/이탈거리를 사용하도록 공유)
  ({int nearestIdx, double distToRoadM, double remainingSegM})? get _lastGeneratedRoadProgress;
  set _lastGeneratedRoadProgress(
      ({int nearestIdx, double distToRoadM, double remainingSegM})? value);

  /// 생성 코스 구간별 도로 폴리라인 (인덱스 N = 이전 waypoint → waypoint[N])
  List<List<NLatLng>> _segmentPolylines = [];

  /// 현재 _segmentPolylines를 채운 API 소스 ('tmap' | 'kakao' | null=미확정).
  /// 세그먼트 0 재요청·재경로 시에도 이 소스를 우선 사용해, 한 코스 안에서
  /// TMAP 구간과 Kakao 구간이 섞이지 않도록 한다.
  String? _generatedCourseRouteSource;

  /// 폴리라인 페치 진행 중일 때 non-null — 동시 요청 간 경쟁 방지용
  Completer<void>? _segmentsFetchCompleter;

  /// 전체 경로 표시 여부 (false = 현재 구간만, true = 완료+현재+예정)
  bool _modeBShowAllSegments = false;

  // BottomSheet 내부 ScrollController (최소화 시 스크롤 리셋용)
  ScrollController? _sheetBScrollCtrl;
  bool _sheetBListenerAdded = false;

  // 네비게이션 폴리라인 실시간 트리밍 캐시
  NPolylineOverlay? _cachedNavRoutePolyline;
  NPolylineOverlay? _cachedNavDonePolyline;
  NPolylineOverlay? _cachedNavSegDonePolyline;
  final Map<int, NPolylineOverlay> _cachedNavSegPolylines = {};
  int _lastTrimGpxIdx = -1;
  int _lastTrimSegIdx = -1;
  bool _lastTrimOffRoute = false;

  /// 현재 지도에 그려져 있는 턴 마커의 오버레이 ID 집합 (_turnMarkerId 기준)
  final Set<String> _drawnTurnMarkerIds = {};

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
      // 코스가 확정한 소스를 그대로 따른다 (세그먼트 0 재요청과 동일한 이유).
      final newPts = await _fetchApproachRoute(
        fromLat: p.latitude,
        fromLng: p.longitude,
        toLat: wp.lat,
        toLng: wp.lng,
        preferredSource: _generatedCourseRouteSource,
      );
      if (!mounted || newPts.length < 2) return;

      _segmentPolylines[currentWpIdx] = newPts;

      await _drawSegmentsOnMap(currentWpIdx, showAll: _modeBShowAllSegments);

      // 재경로 후 nav provider의 구간 거리도 갱신
      final updatedDists = _segmentPolylines.map(_totalPolylineLength).toList();
      ref.read(modeBNavProvider.notifier).updateSegmentDistances(updatedDists);

      // 새 세그먼트 기준으로 턴포인트/위치 인덱스 재계산
      // (_onGeneratedCourseWaypointAdvanced와 동일하게 처리 — 안 하면 재경로 후에도
      // 옛 경로 기준 턴 안내가 남는다)
      final newSeg = _segmentPolylines[currentWpIdx];
      final newSegTurns = newSeg.isNotEmpty
          ? _computeTurnPoints(
              newSeg.map((pt) => (lat: pt.latitude, lng: pt.longitude)).toList(),
              segIdx: currentWpIdx,
            )
          : <_TurnPoint>[];
      _modeBTurnPoints = newSegTurns;
      _modeBRoadNearestPtIdx = 0;
      _lastGeneratedRoadProgress = null;

      // 지도 마커: 이 구간(currentWpIdx)의 턴만 새 경로 기준으로 교체하고
      // 다른 구간의 턴 마커는 그대로 둔다.
      _allRouteTurnMarkers = [
        ..._allRouteTurnMarkers.where((t) => t.segIdx != currentWpIdx),
        ...newSegTurns,
      ];
      if (mounted) {
        unawaited(_drawTurnMarkersOnMap(_allRouteTurnMarkers));
      }
    } catch (_) {}
  }

  // ── 전체 / 현재 구간 표시 토글 ────────────────────────────────────

  void _toggleShowAllSegments(int currentWpIdx) {
    if (!mounted) return;
    setState(() => _modeBShowAllSegments = !_modeBShowAllSegments); // 버튼 시각 갱신
    unawaited(_drawSegmentsOnMap(currentWpIdx, showAll: _modeBShowAllSegments));
  }

  // ── 구간별 도로 경로 일괄 페치 ────────────────────────────────────
  //
  // 코스 전체를 하나의 API 소스로 통일한다: TMAP(도보 정확도가 더 높음)으로
  // 전 구간을 먼저 시도하고, 단 한 구간이라도 실패하면 그 결과는 버리고
  // 코스 전체를 Kakao Mobility로 다시 시도한다. 구간별로 독립적으로
  // TMAP→Kakao 폴백을 판단하면 한 코스 안에서 도로 스냅 스타일이 섞여
  // 부자연스러운 경로가 나올 수 있어, "전체 성공/전체 실패" 단위로만 전환한다.

  Future<void> _fetchAllSegmentPolylines({
    required double startLat,
    required double startLng,
    required List<SpotWaypoint> waypoints,
  }) async {
    final tmapPass = await _fetchSegmentsBySource(
      startLat: startLat, startLng: startLng, waypoints: waypoints, source: 'tmap',
    );
    if (tmapPass.allSucceeded) {
      _segmentPolylines = tmapPass.segments;
      _generatedCourseRouteSource = 'tmap';
      return;
    }

    debugPrint('[ModeB] TMAP으로 코스 전체 구간을 채우지 못해 Kakao로 코스 전체 재시도');
    final kakaoPass = await _fetchSegmentsBySource(
      startLat: startLat, startLng: startLng, waypoints: waypoints, source: 'kakao',
    );
    // kakaoPass도 일부 구간이 실패하면 그 구간은 직선으로 채워져 있다(마지막 안전망) —
    // 그래도 TMAP 결과와 섞지 않고 Kakao 패스 하나로 통일해 사용한다.
    _segmentPolylines = kakaoPass.segments;
    _generatedCourseRouteSource = kakaoPass.allSucceeded ? 'kakao' : null;
  }

  /// [source]("tmap" | "kakao") 하나만으로 전 구간을 시도한다. 실패한 구간은
  /// 직선으로 채우되 [allSucceeded]로 실제 전체 성공 여부를 함께 반환한다.
  Future<({List<List<NLatLng>> segments, bool allSucceeded})> _fetchSegmentsBySource({
    required double startLat,
    required double startLng,
    required List<SpotWaypoint> waypoints,
    required String source,
  }) async {
    final segments = <List<NLatLng>>[];
    var allSucceeded = true;
    double prevLat = startLat, prevLng = startLng;

    for (final wp in waypoints) {
      final pts = source == 'tmap'
          ? await _fetchPedestrianRoute(
              startLat: prevLat, startLng: prevLng,
              waypointCoords: [(lat: wp.lat, lng: wp.lng)],
            )
          : await _fetchKakaoMobilityRoute(prevLat, prevLng, wp.lat, wp.lng);

      if (pts.isNotEmpty) {
        segments.add(_withSnapPrefix(prevLat, prevLng, pts));
      } else {
        segments.add([NLatLng(prevLat, prevLng), NLatLng(wp.lat, wp.lng)]);
        allSucceeded = false;
      }
      prevLat = wp.lat;
      prevLng = wp.lng;
    }
    return (segments: segments, allSucceeded: allSucceeded);
  }

  /// 요청 출발점과 API가 반환한 첫 포인트가 10m 이상 떨어져 있으면 출발점을
  /// 맨 앞에 이어붙인다 (도로 스냅 지점과 실제 출발 위치 사이 끊김 방지).
  List<NLatLng> _withSnapPrefix(double fromLat, double fromLng, List<NLatLng> pts) {
    final snapDist = Geolocator.distanceBetween(
        fromLat, fromLng, pts.first.latitude, pts.first.longitude);
    return snapDist > 10 ? [NLatLng(fromLat, fromLng), ...pts] : pts;
  }

  // ── 구간별 폴리라인 그리기 ────────────────────────────────────────

  Future<void> _drawSegmentsOnMap(int currentWpIdx, {bool showAll = false}) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted || _segmentPolylines.isEmpty) return;

    // context는 await 전에 캡처
    final completedColor = kMapWhite45;
    final upcomingColor = context.colors.accent.withValues(alpha: 0.35);
    final accentColor = context.colors.accent;

    // 구간 교체 시 트리밍 캐시 무효화 (새 폴리라인 인스턴스로 교체되므로)
    _cachedNavSegPolylines.clear();
    _cachedNavSegDonePolyline = null;
    _lastTrimSegIdx = -1;
    _lastTrimOffRoute = false;

    for (var i = 0; i < _segmentPolylines.length; i++) {
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'seg_$i'),
      ).catchError((_) {});
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'seg_done_$i'),
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
    _cachedNavDonePolyline = null;
    _cachedNavSegDonePolyline = null;
    _cachedNavSegPolylines.clear();
    _lastTrimGpxIdx = -1;
    _lastTrimSegIdx = -1;
    _lastTrimOffRoute = false;
    _drawnTurnMarkerIds.clear();
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
      widget: MapRouteMarkerDot(color: c.pinSight, label: '◆'),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return {};
    final homeIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.pinUser, label: '⌂'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final cartIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.primary, label: '★'),
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
      'cart': cartIcon,
    };
    return _modeBMarkerIcons!;
  }

  // ── 장바구니 스팟 마커 추가 (ID: cart_N) ─────────────────────────

  Future<void> _addCartMarkersToMap(List<SpotEntity> items) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted || items.isEmpty) return;
    final icons = await _getModeBMarkerIcons();
    if (!mounted) return;
    final c = context.colors;
    for (var i = 0; i < items.length; i++) {
      final spot = items[i];
      final marker = NMarker(
        id: 'cart_$i',
        position: NLatLng(spot.lat, spot.lng),
        icon: icons['cart'] ?? icons['selected'],
        caption: NOverlayCaption(
          text: spot.name,
          textSize: 11,
          color: c.primary,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      );
      marker.setOnTapListener((_) => _onSpotTap(spot));
      await ctrl.addOverlay(marker);
    }
  }

  Future<void> _refreshCartMarkersOnMap(List<SpotEntity> items) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (var i = 0; i < kCartMaxSpots; i++) {
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: 'cart_$i'),
      ).catchError((_) {});
    }
    if (!mounted || items.isEmpty) return;
    await _addCartMarkersToMap(items);
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

    // 장바구니 스팟은 항상 맵에 고정 표시
    if (!mounted) return;
    final cartItems = ref.read(cartProvider);
    if (cartItems.isNotEmpty) await _addCartMarkersToMap(cartItems);
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

    // 카트에 이미 담긴 스팟은 cart 마커로 표시하므로 search 마커는 생략
    final cartIds = ref.read(cartProvider).map((s) => s.id).toSet();

    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      if (cartIds.contains(spot.id)) continue;
      final marker = NMarker(
        id: 'search_spot_$i',
        position: NLatLng(spot.lat, spot.lng),
        icon: icons['spot'],
        caption: NOverlayCaption(
          text: spot.name,
          textSize: 11,
          color: context.colors.pinSight,
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

    // 장바구니 스팟 마커 (검색 결과 위에 고정 표시)
    if (!mounted) return;
    final cartItems = ref.read(cartProvider);
    if (cartItems.isNotEmpty) await _addCartMarkersToMap(cartItems);

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
          color: context.colors.pinSight,
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
        captionColor = context.colors.pinUser;
      } else {
        icon = await NOverlayImage.fromWidget(
          widget: _StepNumberBadge(number: stepNum),
          size: const Size(32, 32),
          context: context,
        );
        captionText = '$stepNum. ${wp.name}';
        captionColor = context.colors.pinSight;
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
          ? context.colors.warn
          : isOrigin
              ? context.colors.pinUser
              : isDone
                  ? Colors.white30
                  : context.colors.pinSight;
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
      // 같은 태그 재탭 → 해제 + 마커 제거 후 카트 마커 복원
      notifier.selectSpotTag(tag);
      _currentSearchedSpots = [];
      await _ctrl?.clearOverlays(type: NOverlayType.marker);
      await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      if (!mounted) return;
      final cartItems = ref.read(cartProvider);
      if (cartItems.isNotEmpty) await _addCartMarkersToMap(cartItems);
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
      // 이미 활성 → 해제 후 카트 마커 복원
      notifier.toggleNearbyCourses();
      _currentSearchedSpots = [];
      await _ctrl?.clearOverlays(type: NOverlayType.marker);
      await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      if (!mounted) return;
      final cartItems = ref.read(cartProvider);
      if (cartItems.isNotEmpty) await _addCartMarkersToMap(cartItems);
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
      // 미리보기 페치 진행 중이면 완료 대기
      final pendingFetch = _segmentsFetchCompleter;
      if (pendingFetch != null) {
        await pendingFetch.future.catchError((_) {});
      }

      final startLat = pos?.latitude ?? route.startLat!;
      final startLng = pos?.longitude ?? route.startLng!;

      if (_segmentPolylines.length != route.waypoints.length) {
        // 미리보기에서 전혀 페치되지 않은 경우 — 전체 구간 신규 페치
        setState(() => _gpxLoading = true);
        try {
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
        // 스팟↔스팟 구간(1..N-1)은 사용자 위치와 무관하므로 미리보기 결과를 재사용하고,
        // 세그먼트 0(현재 위치 → 첫 스팟)만 안내 시작 시점의 최신 GPS로 다시 요청한다.
        // (재사용만 하면 미리보기 당시 origin이 stale해 파란 접근경로와 어긋나 보이던 원인 —
        //  이제 접근 경로는 별도 오버레이 없이 seg_0 자체가 항상 현재 위치에서 시작한다.)
        await ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
        if (route.waypoints.isNotEmpty) {
          setState(() => _gpxLoading = true);
          try {
            final firstWp = route.waypoints.first;
            // 코스가 이미 확정한 소스(_generatedCourseRouteSource)를 그대로 따른다 —
            // 나머지 구간이 Kakao로 채워진 코스에서 이 구간만 TMAP으로 성공해
            // 소스가 섞이는 것을 방지한다.
            final pts = await _fetchApproachRoute(
              fromLat: startLat, fromLng: startLng,
              toLat: firstWp.lat, toLng: firstWp.lng,
              preferredSource: _generatedCourseRouteSource,
            );
            // 두 API 모두 실패하면 직선으로 대체한다 — 비워두면 미리보기 시점의
            // stale한 세그먼트 0(옛 위치 기준)이 그대로 남는 문제가 재발한다.
            _segmentPolylines[0] =
                pts.isNotEmpty ? pts : [NLatLng(startLat, startLng), NLatLng(firstWp.lat, firstWp.lng)];
          } finally {
            if (mounted) setState(() => _gpxLoading = false);
          }
        }
      }

      // 내비게이션 시작: 전체 구간 표시 (완료=회색, 예정=옅은노랑, 현재=노랑)
      if (mounted) {
        setState(() => _modeBShowAllSegments = true);
        await _drawSegmentsOnMap(0, showAll: true);
      }
      if (mounted) await _drawNavSpotMarkers(route.waypoints, currentIdx: 0);
    } else {
      // 기성(GPX) 코스: 현재 위치 → 코스 시작점 접근 구간을 별도 오버레이가 아니라
      // gpxPoints 앞에 이어붙여 단일 폴리라인으로 만든다. 이렇게 하면 렌더링과
      // 이탈/잔여거리 판정(_updateGpxNav)이 동일한 좌표 배열을 기준으로 계산되어
      // 접근 구간에서 발생하던 오탐 이탈이 함께 해결된다.
      List<NLatLng> approachPts = [];
      if (ctrl != null && route.hasCoordinate && pos != null) {
        setState(() => _gpxLoading = true);
        try {
          final results = await Future.wait<List<NLatLng>>([
            _fetchApproachRoute(
              fromLat: pos.latitude, fromLng: pos.longitude,
              toLat: route.startLat!, toLng: route.startLng!,
            ),
            route.gpxpath != null
                ? _fetchGpxPoints(route.gpxpath!)
                : Future.value(const <NLatLng>[]),
          ]);
          approachPts = results[0];
          gpxPoints = results[1];
        } finally {
          if (mounted) setState(() => _gpxLoading = false);
        }
      } else if (route.gpxpath != null) {
        setState(() => _gpxLoading = true);
        try {
          gpxPoints = await _fetchGpxPoints(route.gpxpath!);
        } finally {
          if (mounted) setState(() => _gpxLoading = false);
        }
      }

      if (approachPts.isNotEmpty) {
        gpxPoints = [...approachPts, ...gpxPoints];
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

  /// 단일 구간 접근 경로 조회. [preferredSource]가 'kakao'면 TMAP을 건너뛰고
  /// 바로 Kakao를 시도한다 — 이미 코스 전체가 Kakao로 확정된 상태(세그먼트 0
  /// 재요청·재경로)에서 이 구간만 TMAP으로 성공해 코스 안에 소스가 섞이는
  /// 것을 막기 위함. 그 외에는 TMAP 우선 → Kakao 폴백.
  Future<List<NLatLng>> _fetchApproachRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? preferredSource,
  }) async {
    if (preferredSource != 'kakao') {
      final pedestrianPts = await _fetchPedestrianRoute(
        startLat: fromLat,
        startLng: fromLng,
        waypointCoords: [(lat: toLat, lng: toLng)],
      );
      if (pedestrianPts.isNotEmpty) {
        return _withSnapPrefix(fromLat, fromLng, pedestrianPts);
      }
    }

    final kakaoPts = await _fetchKakaoMobilityRoute(fromLat, fromLng, toLat, toLng);
    return kakaoPts.isNotEmpty ? _withSnapPrefix(fromLat, fromLng, kakaoPts) : kakaoPts;
  }

  Future<List<NLatLng>> _fetchKakaoMobilityRoute(
    double fromLat, double fromLng, double toLat, double toLng,
  ) async {
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

    // 이전에 그려둔 턴 마커를 전부 지운다 — 내용 기반 ID(_turnMarkerId)를 추적하므로
    // 개수 추정 없이 정확히 그 마커들만 지울 수 있다.
    for (final id in _drawnTurnMarkerIds) {
      await ctrl.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: id),
      ).catchError((_) {});
    }
    _drawnTurnMarkerIds.clear();
    if (!mounted) return;

    for (final turn in turns) {
      if (turn.type == _TurnType.straight || turn.type == _TurnType.arrival) continue;

      final icon = await NOverlayImage.fromWidget(
        widget: _TurnDirectionMarker(type: turn.type),
        size: const Size(28, 28),
        context: ctx,
      );
      if (!mounted) break;

      final id = _turnMarkerId(turn);
      await ctrl.addOverlay(NMarker(
        id: id,
        position: NLatLng(turn.lat, turn.lng),
        icon: icon,
        anchor: const NPoint(0.5, 0.5),
        isHideCollidedMarkers: false,
      ));
      _drawnTurnMarkerIds.add(id);
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
    final offRouteColor = context.colors.warn;

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

      // 이탈이 아니면 항상 accent(노랑) — 생성 코스와 동일한 진행중 색상으로 통일
      final polylineColor = isOffRoute ? offRouteColor : c.accent;

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

      // 완료 구간(시작 ~ 현재 위치)을 회색으로 표시 — 생성 코스와 동일한 색상 규칙
      // (기성 GPX 코스는 웨이포인트가 없는 단일 트랙이므로 완료/진행중 2단계로 표시)
      if (startIdx != _lastTrimGpxIdx) {
        final donePts = pts
            .sublist(0, startIdx + 1)
            .map((pt) => NLatLng(pt.lat, pt.lng))
            .toList();
        if (donePts.length >= 2) {
          final doneCached = _cachedNavDonePolyline;
          if (doneCached != null) {
            doneCached.setCoords(donePts);
          } else {
            await ctrl.deleteOverlay(
              NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'route_done'),
            ).catchError((_) {});
            if (!mounted) return;
            final donePoly = NPolylineOverlay(
              id: 'route_done',
              coords: donePts,
              color: kMapWhite45,
              width: 4,
              lineCap: NLineCap.round,
              lineJoin: NLineJoin.round,
            );
            await ctrl.addOverlay(donePoly);
            if (mounted) _cachedNavDonePolyline = donePoly;
          }
        }
      }

      _lastTrimGpxIdx = startIdx;
      _lastTrimOffRoute = isOffRoute;

    } else if (route.isGenerated && _segmentPolylines.isNotEmpty) {
      // 생성 코스는 단계별/전체보기 모드와 무관하게 seg_N 폴리라인이 항상 표시되므로
      // (_toggleNavStepMode 참고) 단계별 모드에서도 트리밍을 계속 갱신해야 한다.
      final currentIdx =
          navState.currentWaypointIdx.clamp(0, _segmentPolylines.length - 1);
      final pts = _segmentPolylines[currentIdx];
      if (pts.isEmpty) return;

      // _onModeBNavPositionUpdate에서 이번 GPS 틱에 이미 계산한 도로 스냅 진행률을
      // 재사용 — 렌더링 색상이 provider의 도착/이탈 판정과 항상 동일한 값을 근거로 한다.
      final progress = _lastGeneratedRoadProgress;
      if (progress == null) return;
      final nearestIdx = progress.nearestIdx.clamp(0, pts.length - 1);
      final isOffRoute = progress.distToRoadM > AppConstants.modeBOffRouteThresholdM;

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

      // 현재 구간 내에서 지나온 부분(구간 시작 ~ 현재 위치)을 실시간으로 회색 표시
      if (nearestIdx != _lastTrimSegIdx) {
        final donePts = pts.sublist(0, nearestIdx + 1);
        if (donePts.length >= 2) {
          final doneCached = _cachedNavSegDonePolyline;
          if (doneCached != null) {
            doneCached.setCoords(donePts);
          } else {
            await ctrl.deleteOverlay(
              NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'seg_done_$currentIdx'),
            ).catchError((_) {});
            if (!mounted) return;
            final donePoly = NPolylineOverlay(
              id: 'seg_done_$currentIdx',
              coords: donePts,
              color: kMapWhite45,
              width: 4,
              lineCap: NLineCap.round,
              lineJoin: NLineJoin.round,
            );
            await ctrl.addOverlay(donePoly);
            if (mounted) _cachedNavSegDonePolyline = donePoly;
          }
        }
      }

      _lastTrimSegIdx = nearestIdx;
      _lastTrimOffRoute = isOffRoute;
    }
  }

  // ── Mode B overlay widgets ─────────────────────────────────────

  /// 뒤로가기 스택이 비어 있을 수 있음 (splash 복원·검색화면에서 go()로 진입한 경우).
  /// context.pop()만 쓰면 "There is nothing to pop" 에러가 나므로,
  /// pop 가능 여부를 먼저 확인하고 불가능하면 음식 선택 화면으로 명시적 이동한다.
  void _modeBSafeBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/mode-b');
    }
  }

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
              _ModeBTopBar(food: food, onBack: _modeBSafeBack),
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
            onBack: _modeBSafeBack,
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
              onTransportChange: (v) async {
                final notifier = ref.read(routeSearchProvider.notifier);
                notifier.setTransport(v, food,
                    lat: _position?.latitude ?? 37.5635,
                    lng: _position?.longitude ?? 126.9869);
                // 맞춤 코스 프리뷰 초기화
                _segmentPolylines = [];
                _generatedCourseRouteSource = null;
                await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
                await _ctrl?.clearOverlays(type: NOverlayType.marker);
                if (!mounted) return;
                final cartItems = ref.read(cartProvider);
                if (cartItems.isNotEmpty) await _addCartMarkersToMap(cartItems);
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
        color: context.colors.pinSight,
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
