part of '../map_overlay.dart';

mixin _ModeBNavOverlayMixin on ConsumerState<MapOverlay> {
  // ── State ──────────────────────────────────────────────────────
  bool _modeBNavCameraFollow = true;
  bool _modeBNavCameraUpdating = false;
  double _modeBNavLastBearing = 0.0;
  Position? _modeBNavPrevPosition;

  /// true = 북쪽 고정 (north-up), false = 이동 방향 (heading-up, 기본)
  bool _modeBNorthUpMode = false;

  /// 생성 코스 스팟 캐러셀 현재 페이지 인덱스
  int _modeBNavWaypointPageIdx = 0;

  /// 생성 코스 이탈 시작 시각 (30초 유지 시 재경로)
  DateTime? _offRouteStartTime;

  /// 단계별 안내 모드 (GPX 코스 + 생성 코스 공통)
  bool _modeBNavStepMode = false;

  /// 경로에서 추출한 방향 전환 포인트 목록 — 현재 구간(생성 코스) 또는 전체 트랙(GPX)
  /// 기준. 단계별 안내 카드(다음 턴 문구·거리)에만 쓰인다.
  List<TurnPoint> _modeBTurnPoints = [];

  /// 지도 위에 표시되는 "코스 전체" 턴 마커 목록. _modeBTurnPoints와 달리 생성 코스도
  /// 모든 구간의 턴을 한번에 담고 있어, 지도를 보면 코스 전체의 좌우회전 지점이
  /// 한눈에 보인다. 사용자가 지나간 턴은 실시간으로 이 목록과 지도에서 제거된다.
  List<TurnPoint> _allRouteTurnMarkers = [];

  /// 단계별 세그먼트 폴리라인 마지막 갱신 시각 (스로틀)
  DateTime? _lastStepSegmentUpdate;

  /// 현재 구간 도로 경로 상의 현재 위치 인덱스 (단계별 모드용)
  int _modeBRoadNearestPtIdx = 0;

  /// 생성 코스: 도로 스냅 폴리라인 기준 이번 GPS 틱의 진행률 계산 결과.
  /// 틱당 1회만 계산해 provider 갱신·폴리라인 트리밍·자동 재경로 판정이
  /// 모두 동일한 값을 공유하도록 한다(중복 계산으로 인한 판정 불일치 방지).
  ({int nearestIdx, double distToRoadM, double remainingSegM})?
  _lastGeneratedRoadProgress;

  /// 네비게이션 시작 이후 누적 이동 거리 (자동 단계별 전환 트리거)
  double _movedSinceNavStart = 0.0;

  /// 도착 처리 중복 방지 플래그
  bool _arrivalHandled = false;

  NaverMapController? get _ctrl;
  Position? get _position;

  /// 기기 나침반 방위각 (map_overlay.dart의 _compassHeading 필드로 구현)
  double get _compassHeading;

  // mode_b_mixin에서 구현
  DraggableScrollableController get _sheetBCtrl;
  Future<List<NLatLng>> _fetchGpxPoints(String gpxUrl);
  List<List<NLatLng>> get _segmentPolylines;
  bool get _modeBShowAllSegments;
  Future<void> _drawSegmentsOnMap(int currentWpIdx, {bool showAll = false});
  void _toggleShowAllSegments(int currentWpIdx);
  Future<void> _rerouteGeneratedCourse(
    Position p,
    TouristRouteEntity route,
    int wpIdx,
  );
  Future<void> _drawTurnMarkersOnMap(List<TurnPoint> turns);
  Set<String> get _drawnTurnMarkerIds;
  Future<void> _drawNavSpotMarkers(
    List<SpotWaypoint> waypoints, {
    required int currentIdx,
  });
  void _clearNavPolylineCache();
  List<SpotEntity> get _currentSearchedSpots;
  Future<void> _drawSearchedSpotMarkers(List<SpotEntity> spots);
  Future<void> _updateModeBMarkers(
    List<TouristRouteEntity> routes, {
    int selectedIdx,
  });
  Future<void> _addCartMarkersToMap(List<SpotEntity> items);

  void _disposeModeBNav() {
    _clearNavPolylineCache();
  }

  // ── Navigation 시작 ───────────────────────────────────────────

  Future<void> _startModeBNavigation(
    TouristRouteEntity route,
    List<NLatLng> gpxPoints, {
    List<double> segmentDistancesM = const [],
  }) async {
    final food = ref.read(selectedFoodProvider);
    final gpxPts = gpxPoints
        .map((p) => (lat: p.latitude, lng: p.longitude))
        .toList();

    await ref
        .read(modeBNavProvider.notifier)
        .start(
          route: route,
          gpxPoints: gpxPts,
          foodKcal: food?.kcal ?? 0,
          foodName: food?.name ?? '',
          segmentDistancesM: segmentDistancesM,
        );

    if (mounted) {
      setState(() {
        _modeBNavCameraFollow = true;
        _modeBNavCameraUpdating = false;
        _modeBNavLastBearing = 0.0;
        _modeBNavPrevPosition = null;
        _modeBNavStepMode = false;
        _modeBRoadNearestPtIdx = 0;
        _lastGeneratedRoadProgress = null;
        _movedSinceNavStart = 0.0;
        _arrivalHandled = false;
      });
    }

    // 방향 전환 포인트 계산 — GPX 코스: 전체, 생성 코스: 첫 번째 구간
    if (!route.isGenerated && gpxPoints.isNotEmpty) {
      final pts = gpxPoints
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList();
      _modeBTurnPoints = computeTurnPoints(pts);
      // GPX는 구간이 없는 단일 트랙이라 _modeBTurnPoints가 이미 전체 경로 기준이다.
      _allRouteTurnMarkers = List.of(_modeBTurnPoints);
    } else if (route.isGenerated && _segmentPolylines.isNotEmpty) {
      final firstSeg = _segmentPolylines[0];
      if (firstSeg.isNotEmpty) {
        final pts = firstSeg
            .map((p) => (lat: p.latitude, lng: p.longitude))
            .toList();
        _modeBTurnPoints = computeTurnPoints(pts);
      } else {
        _modeBTurnPoints = [];
      }
      _modeBRoadNearestPtIdx = 0;
      // 지도 마커는 현재 구간뿐 아니라 코스 전체 구간의 턴을 한번에 표시한다.
      _allRouteTurnMarkers = _computeAllGeneratedRouteTurnPoints();
    } else {
      _modeBTurnPoints = [];
      _allRouteTurnMarkers = [];
    }
    // 턴 마커 그리기 — 실제 턴이 없어도 항상 호출해 이전 구간의 마커를 정리한다
    // (조건부로만 호출하면 새 구간에 턴이 없을 때 이전 마커가 지도에 남는다).
    if (mounted) {
      unawaited(_drawTurnMarkersOnMap(_allRouteTurnMarkers));
    }

    // 시트 접기
    if (_sheetBCtrl.isAttached) {
      _sheetBCtrl.animateTo(
        0.13,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 현재 위치로 카메라
    final pos = _position;
    if (pos != null) {
      await _followModeBCamera(pos.latitude, pos.longitude, 0);
    }
  }

  // ── Navigation 종료 ───────────────────────────────────────────

  /// 안내 종료 공통 정리: provider 상태 리셋, 로컬 플래그·턴 마커 리셋, 폴리라인 캐시
  /// 정리, 지도 오버레이 삭제, 카메라 원위치. 수동 종료(_stopModeBNavigation)·도착
  /// (_checkModeBNavArrival)·뒤로가기 확인 모두 이 함수 하나로 처리해, 한쪽만 고치고
  /// 다른 쪽은 빠뜨리는 일이 없도록 한다 — 과거엔 도착 시에는 이 정리가 전혀 호출되지
  /// 않아 완주 후에도 폴리라인·턴 마커가 지도에 그대로 남아있던 버그가 있었다.
  /// [alreadySaved]가 true면 기록 저장을 건너뛴다(도착 처리에서 이미 저장한 경우).
  Future<void> _resetModeBNavState({bool alreadySaved = false}) async {
    final navState = ref.read(modeBNavProvider);
    if (!alreadySaved && navState.isNavigating && navState.elapsedKcal >= 1.0) {
      await _saveModeBRecord(navState);
    }
    // 자전거 코스만 홈 화면 "오늘" 총합에 병합한다 — 도보는 페도미터가 이미 실제
    // 걸음을 세고 있어 중복 계산을 막기 위해 제외한다. 도착/도중 종료 모두 이
    // 함수 하나로 처리되므로(위 주석 참고) 여기 한 곳만 고치면 된다.
    if (navState.isNavigating &&
        navState.route?.type == '자전거' &&
        navState.elapsedKcal >= 1.0) {
      final distM = (navState.route!.distanceKm * 1000) * navState.kcalProgress;
      ref
          .read(walkSessionProvider.notifier)
          .addExternalKcal(kcal: navState.elapsedKcal, distanceM: distM);
    }
    await ref.read(modeBNavProvider.notifier).stop();

    if (!mounted) return;
    setState(() {
      _modeBNavCameraFollow = true;
      _modeBNavCameraUpdating = false;
      _modeBNavLastBearing = 0.0;
      _modeBNavPrevPosition = null;
      _modeBNorthUpMode = false;
      _modeBNavWaypointPageIdx = 0;
      _modeBNavStepMode = false;
      _modeBTurnPoints = [];
      _allRouteTurnMarkers = [];
      _lastStepSegmentUpdate = null;
      _modeBRoadNearestPtIdx = 0;
      _lastGeneratedRoadProgress = null;
    });

    _arrivalHandled = false;
    _clearNavPolylineCache();

    // 안내 중 그려진 폴리라인·마커(seg_N, route_path, route_done, turn_N, nav_spot_N 등)를
    // 실제로 지도에서 제거한다. 위의 _clearNavPolylineCache()는 내부 캐시 참조만 비울 뿐
    // NaverMap 오버레이 자체는 지우지 않는다.
    final ctrl = _ctrl;
    if (ctrl != null) {
      await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
      await ctrl.clearOverlays(type: NOverlayType.marker);
    }

    // 카메라 초기화
    final pos = _position;
    if (ctrl != null && pos != null) {
      await ctrl.updateCamera(
        NCameraUpdate.withParams(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 15,
          bearing: 0,
          tilt: 0,
        )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  /// 안내 종료 후(food가 남아있으면) 탐색 화면 상태(카트/검색결과/기성코스)에 맞춰
  /// 마커를 복원한다. 방금 _resetModeBNavState가 마커를 모두 지웠으므로 필요하다.
  void _restoreModeBExploreMarkersIfAny() {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final modeBState = ref.read(routeSearchProvider);
    if (_currentSearchedSpots.isNotEmpty) {
      unawaited(_drawSearchedSpotMarkers(_currentSearchedSpots));
    } else if (modeBState.searchedSpots.isNotEmpty) {
      unawaited(_drawSearchedSpotMarkers(modeBState.searchedSpots));
    } else if (modeBState.routes.isNotEmpty) {
      unawaited(
        _updateModeBMarkers(
          modeBState.routes,
          selectedIdx: modeBState.selectedRouteIdx,
        ),
      );
    } else {
      final cartItems = ref.read(cartProvider);
      if (cartItems.isNotEmpty) unawaited(_addCartMarkersToMap(cartItems));
    }
  }

  Future<void> _stopModeBNavigation() async {
    await _resetModeBNavState();

    // 종료 후 화면 처리: 음식이 없으면 (앱 재시작 복원 케이스) mode-b 선택으로
    if (!mounted) return;
    final food = ref.read(selectedFoodProvider);
    if (food == null) {
      context.go('/mode-b'); // ignore: use_build_context_synchronously
      return;
    }
    // food가 있으면 mode_b 탐색 화면 자동 복귀
    _restoreModeBExploreMarkersIfAny();
  }

  // ── GPS 위치 업데이트 처리 ─────────────────────────────────────

  void _onModeBNavPositionUpdate(Position p, ModeBNavState navState) {
    if (!navState.isNavigating) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    final metrics = profile?.toBodyMetrics() ?? BodyMetrics.defaultMetrics;
    final route = navState.route;
    final transport = route?.type == '자전거' ? 'bike' : 'walk';
    final prevWpIdx = navState.currentWaypointIdx;

    final isGenerated =
        route != null && route.isGenerated && route.waypoints.isNotEmpty;
    final segmentsReady =
        isGenerated &&
        _segmentPolylines.isNotEmpty &&
        prevWpIdx < _segmentPolylines.length;

    // 이번 틱에 계산한 진행률 — provider 갱신뿐 아니라 아래 지나간 턴 마커 제거에도 재사용
    ({int nearestIdx, double distToRoadM, double remainingSegM})? progress;

    if (segmentsReady) {
      // 화면에 그려지는 도로 스냅 폴리라인(_segmentPolylines) 기준으로 진행률을
      // 틱당 1회만 계산 — provider 갱신·트리밍 색상·자동 재경로 판정이 모두 이 값을 공유한다.
      progress = _computeGeneratedRoadProgress(
        p.latitude,
        p.longitude,
        prevWpIdx,
      );
      _lastGeneratedRoadProgress = progress;

      final target = route.waypoints[prevWpIdx];
      final distToTargetM = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        target.lat,
        target.lng,
      );

      ref
          .read(modeBNavProvider.notifier)
          .updateGeneratedFromRoad(
            lat: p.latitude,
            lng: p.longitude,
            distToTargetM: distToTargetM,
            distToRoadM: progress.distToRoadM,
            remainingSegM: progress.remainingSegM,
            metrics: metrics,
            transport: transport,
          );
    } else {
      ref
          .read(modeBNavProvider.notifier)
          .onPositionUpdate(p.latitude, p.longitude, metrics, transport);
    }

    final updatedState = ref.read(modeBNavProvider);
    final newWpIdx = updatedState.currentWaypointIdx;
    final wpAdvanced = newWpIdx != prevWpIdx;
    // 세그먼트가 바뀌면 이전 세그먼트 기준 위치 인덱스는 새 세그먼트에 무의미하므로
    // _onGeneratedCourseWaypointAdvanced(비동기)가 처리하기 전에 이번 틱에서 즉시 리셋한다.
    if (wpAdvanced) {
      _modeBRoadNearestPtIdx = 0;
      _lastGeneratedRoadProgress = null;
    }

    // 지나온 턴 마커 제거 — 완료된 코스 구간이 회색으로 바뀌는 것과 동일하게,
    // 사용자가 실제로 지나친 좌/우회전 아이콘도 실시간으로 지도에서 사라지게 한다.
    if (isGenerated) {
      // wpAdvanced가 이번 틱에 막 일어났으면 progress는 "이전" 구간 기준이라
      // 새 구간(newWpIdx)의 턴과 비교하면 안 된다 — segIdx 비교만으로 이전 구간
      // 전체는 이미 걸러지므로 ptIdx 비교는 생략(-1)한다.
      final ptIdx = wpAdvanced ? -1 : (progress?.nearestIdx ?? -1);
      _pruneRouteTurnMarkers(currentSegIdx: newWpIdx, currentPtIdx: ptIdx);
    } else {
      _pruneRouteTurnMarkers(
        currentSegIdx: 0,
        currentPtIdx: updatedState.nearestGpxPtIdx,
      );
    }

    // 이동 방향 계산 (GPS 기반)
    final prev = _modeBNavPrevPosition;
    double movedNow = 0.0;
    if (prev != null) {
      final bearing = _calcModeBBearing(
        prev.latitude,
        prev.longitude,
        p.latitude,
        p.longitude,
      );
      movedNow = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        p.latitude,
        p.longitude,
      );
      if (movedNow >= 2.0) _modeBNavLastBearing = bearing;
    }
    _modeBNavPrevPosition = p;

    if (_modeBNavCameraFollow) {
      final cameraBearing = _modeBNorthUpMode ? 0.0 : _compassHeading;
      _followModeBCamera(p.latitude, p.longitude, cameraBearing);
    }

    // 자동 단계별 전환: 생성 코스에서 50m 이동 시
    if (!_modeBNavStepMode && isGenerated) {
      if (movedNow >= 2.0) {
        _movedSinceNavStart += movedNow;
        if (_movedSinceNavStart >= 50.0) {
          final hasRealTurns = _modeBTurnPoints.any(
            (t) => t.type != TurnType.arrival,
          );
          if (hasRealTurns && mounted) {
            setState(() => _modeBNavStepMode = true);
          }
        }
      }
    }

    // 단계별 모드: GPX 코스 전용 세그먼트 갱신
    if (_modeBNavStepMode &&
        !isGenerated &&
        _modeBTurnPoints.any((t) => t.type != TurnType.arrival)) {
      unawaited(_updateStepModeSegment(updatedState));
    }

    // 생성 코스: 다음 waypoint 도착 감지 → 구간 교체
    if (isGenerated && wpAdvanced) {
      unawaited(
        _onGeneratedCourseWaypointAdvanced(updatedState.route!, newWpIdx),
      );
    }

    // GPX 코스 이탈 스낵바는 map_overlay.dart의 ref.listen(modeBNavProvider)에서
    // isOffRoute 전환을 감지해 단일 지점에서 처리한다 (여기서 중복 트리거하지 않음).

    // 생성 코스 이탈 감지 → 30초 유지 시 자동 재경로.
    // 위에서 이미 계산한 도로까지 거리(distToRoadM)를 재사용해 서로 다른 판정 기준이
    // 생기지 않도록 한다.
    if (isGenerated && !wpAdvanced) {
      final progress = _lastGeneratedRoadProgress;
      if (progress != null) {
        if (progress.distToRoadM > AppConstants.offRouteThresholdM) {
          _offRouteStartTime ??= DateTime.now();
          if (DateTime.now().difference(_offRouteStartTime!).inSeconds >= 30) {
            _offRouteStartTime = null;
            _showGeneratedOffRouteDialog(p, route, prevWpIdx);
          }
        } else {
          _offRouteStartTime = null;
        }
      }
    }
  }

  /// 도로 스냅 폴리라인(_segmentPolylines[currentWpIdx]) 기준 최근접점 탐색.
  /// GPS 지터로 인덱스가 잘못 앞으로 튀는 문제를 줄이기 위해 소폭 역탐색을 허용한다
  /// (순증가 전용이 아님) — 화면에 그려지는 경로와 동일한 데이터를 사용하므로
  /// 이 결과가 도착/이탈/잔여거리 판정의 유일한 근거가 된다.
  ({int nearestIdx, double distToRoadM, double remainingSegM})
  _computeGeneratedRoadProgress(double lat, double lng, int currentWpIdx) {
    final pts = _segmentPolylines[currentWpIdx];
    final searchStart = (_modeBRoadNearestPtIdx - 30).clamp(0, pts.length - 1);
    final searchEnd = (_modeBRoadNearestPtIdx + 200).clamp(0, pts.length);
    int best = _modeBRoadNearestPtIdx.clamp(0, pts.length - 1);
    double bestDist = double.infinity;
    for (int i = searchStart; i < searchEnd; i++) {
      final d = _preciseDistM(lat, lng, pts[i].latitude, pts[i].longitude);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    _modeBRoadNearestPtIdx = best;

    double remainingSegM = 0;
    for (int i = best; i < pts.length - 1; i++) {
      remainingSegM += _preciseDistM(
        pts[i].latitude,
        pts[i].longitude,
        pts[i + 1].latitude,
        pts[i + 1].longitude,
      );
    }
    return (
      nearestIdx: best,
      distToRoadM: bestDist,
      remainingSegM: remainingSegM,
    );
  }

  // 생성 코스 waypoint 진행 시 호출 — 구간 교체 + 턴 포인트 재계산
  Future<void> _onGeneratedCourseWaypointAdvanced(
    TouristRouteEntity route,
    int newWpIdx,
  ) async {
    if (!mounted) return;
    if (newWpIdx >= route.waypoints.length) return;

    // 폴리라인 교체
    await _drawSegmentsOnMap(newWpIdx, showAll: _modeBShowAllSegments);

    // 새 구간의 턴 포인트 계산 (단계별 안내 카드용 — 지도 마커는 _allRouteTurnMarkers가
    // 이미 코스 전체를 커버하고 있어 여기서 다시 그릴 필요 없다. _drawTurnMarkersOnMap을
    // 이 구간만으로 다시 호출하면 다른 구간의 마커까지 전부 지워지므로 호출하지 않는다 —
    // 지나온 구간의 마커 정리는 다음 GPS 틱의 _pruneRouteTurnMarkers가 담당한다).
    if (newWpIdx < _segmentPolylines.length) {
      final seg = _segmentPolylines[newWpIdx];
      if (seg.isNotEmpty) {
        final pts = seg
            .map((p) => (lat: p.latitude, lng: p.longitude))
            .toList();
        _modeBTurnPoints = computeTurnPoints(pts, legIdx: newWpIdx);
      } else {
        _modeBTurnPoints = [];
      }
    } else {
      _modeBTurnPoints = [];
    }
    _modeBRoadNearestPtIdx = 0;
    _lastGeneratedRoadProgress = null;
    // nav spot 마커 갱신은 modeBNavProvider listener에서 처리
  }

  void _toggleNorthUpMode() {
    if (!mounted) return;
    setState(() => _modeBNorthUpMode = !_modeBNorthUpMode);
    final pos = _position;
    if (pos != null && _modeBNavCameraFollow) {
      final bearing = _modeBNorthUpMode ? 0.0 : _modeBNavLastBearing;
      _followModeBCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  // ── 단계별 안내 모드 토글 ─────────────────────────────────────

  Future<void> _toggleNavStepMode() async {
    if (!mounted) return;
    final navState = ref.read(modeBNavProvider);
    final isGenerated = navState.route?.isGenerated ?? false;
    setState(() => _modeBNavStepMode = !_modeBNavStepMode);

    if (isGenerated) {
      // 생성 코스: seg_N 폴리라인은 항상 유지 — 단계별 ON/OFF는 UI 카드만 전환
      // 단계별 OFF 시 "전체 경로" 아이콘 버튼이 전체 보기 역할
      await _drawSegmentsOnMap(
        navState.currentWaypointIdx,
        showAll: _modeBShowAllSegments,
      );
    } else {
      // GPX 코스: 단계별 ON → step_segment 추가, OFF → 제거하고 route_path 복원
      final ctrl = _ctrl;
      if (ctrl == null) return;

      if (_modeBNavStepMode) {
        unawaited(_updateStepModeSegment(navState));
      } else {
        await ctrl
            .deleteOverlay(
              NOverlayInfo(
                type: NOverlayType.polylineOverlay,
                id: 'step_segment',
              ),
            )
            .catchError((_) {});
        if (!mounted) return;
        final c = context.colors;
        final pts = navState.gpxPoints;
        final startIdx = navState.nearestGpxPtIdx;
        if (pts.length > startIdx + 1) {
          final remaining = pts
              .sublist(startIdx)
              .map((p) => NLatLng(p.lat, p.lng))
              .toList();
          final routeColor = navState.route?.type == '자전거' ? c.warn : c.primary;
          await ctrl.addOverlay(
            NPolylineOverlay(
              id: 'route_path',
              coords: remaining,
              color: routeColor,
              width: 5,
              lineCap: NLineCap.round,
              lineJoin: NLineJoin.round,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateStepModeSegment(ModeBNavState navState) async {
    // 생성 코스는 seg_N 폴리라인이 항상 표시됨 — 별도 step_segment 불필요
    if (navState.route?.isGenerated ?? false) return;

    final now = DateTime.now();
    if (_lastStepSegmentUpdate != null &&
        now.difference(_lastStepSegmentUpdate!).inSeconds < 3) {
      return;
    }
    _lastStepSegmentUpdate = now;

    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    if (_modeBTurnPoints.isEmpty) return;

    final pts = _activeNavPts(navState);
    if (pts.isEmpty) return;

    final nearestIdx = _activeNearestIdx(navState);
    final nextTurnGpxIdx = _getNextTurnGpxIdx(nearestIdx);
    final endIdx = (nextTurnGpxIdx > 0 ? nextTurnGpxIdx : pts.length - 1).clamp(
      0,
      pts.length - 1,
    );
    final startIdx = nearestIdx.clamp(0, pts.length - 1);
    if (endIdx - startIdx < 1) return;

    final segment = pts
        .sublist(startIdx, endIdx + 1)
        .map((p) => NLatLng(p.lat, p.lng))
        .toList();

    // GPX 코스: route_path는 건드리지 않고 step_segment를 위에 덧그림
    await ctrl
        .deleteOverlay(
          NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'step_segment'),
        )
        .catchError((_) {});
    if (!mounted) return;

    final c = context.colors;
    final routeColor = navState.route?.type == '자전거' ? c.warn : c.primary;
    await ctrl.addOverlay(
      NPolylineOverlay(
        id: 'step_segment',
        coords: segment,
        color: routeColor,
        width: 6,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      ),
    );
  }

  int _getNextTurnGpxIdx(int nearestIdx) {
    for (final t in _modeBTurnPoints) {
      if (t.ptIdx > nearestIdx) return t.ptIdx;
    }
    return -1;
  }

  /// GPX 코스: navState.gpxPoints, 생성 코스: 현재 구간 포인트
  List<({double lat, double lng})> _activeNavPts(ModeBNavState navState) {
    if (navState.route?.isGenerated ?? false) {
      final currentIdx = navState.currentWaypointIdx;
      if (_segmentPolylines.isEmpty || currentIdx >= _segmentPolylines.length) {
        return [];
      }
      return _segmentPolylines[currentIdx]
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList();
    }
    return navState.gpxPoints;
  }

  /// GPX 코스: navState.nearestGpxPtIdx, 생성 코스: _modeBRoadNearestPtIdx
  int _activeNearestIdx(ModeBNavState navState) {
    return (navState.route?.isGenerated ?? false)
        ? _modeBRoadNearestPtIdx
        : navState.nearestGpxPtIdx;
  }

  // ── 방향 전환 포인트 계산 ──────────────────────────────────────
  // 알고리즘 자체(거리 윈도우·임계값)는 core/utils/turn_point_utils.dart의
  // computeTurnPoints를 그대로 쓴다 (Mode A와 동일 엔진 — 아래는 Mode B 전용 응용).

  /// 생성 코스: _segmentPolylines 전 구간을 순회하며 턴 포인트를 계산해
  /// 하나의 리스트로 합친다 — 지도에는 현재 구간뿐 아니라 코스 전체의
  /// 좌우회전 지점이 한 번에 표시된다.
  List<TurnPoint> _computeAllGeneratedRouteTurnPoints() {
    final all = <TurnPoint>[];
    for (var legIdx = 0; legIdx < _segmentPolylines.length; legIdx++) {
      final seg = _segmentPolylines[legIdx];
      if (seg.isEmpty) continue;
      final pts = seg.map((p) => (lat: p.latitude, lng: p.longitude)).toList();
      all.addAll(computeTurnPoints(pts, legIdx: legIdx));
    }
    return all;
  }

  /// 사용자가 지나온 턴 마커를 목록·지도에서 제거한다.
  /// [currentSegIdx]: 현재 위치가 속한 구간(생성 코스는 currentWaypointIdx, GPX는 항상 0)
  /// [currentPtIdx]: 그 구간 내에서의 최근접점 인덱스 — currentSegIdx로 막 넘어온 틱에는
  ///   이전 구간 기준 값이라 의미가 없으므로 -1을 넘겨 "이 구간의 부분 통과분"은
  ///   판정에서 제외한다(legIdx 비교만으로 이전 구간 전체는 이미 걸러진다).
  void _pruneRouteTurnMarkers({
    required int currentSegIdx,
    required int currentPtIdx,
  }) {
    if (_allRouteTurnMarkers.isEmpty) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;

    final remaining = <TurnPoint>[];
    for (final t in _allRouteTurnMarkers) {
      final passed =
          t.legIdx < currentSegIdx ||
          (t.legIdx == currentSegIdx &&
              currentPtIdx >= 0 &&
              t.ptIdx <= currentPtIdx);
      if (passed) {
        final id = turnMarkerId(t);
        _drawnTurnMarkerIds.remove(id);
        unawaited(
          ctrl
              .deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id))
              .catchError((_) {}),
        );
      } else {
        remaining.add(t);
      }
    }
    if (remaining.length != _allRouteTurnMarkers.length) {
      _allRouteTurnMarkers = remaining;
    }
  }

  /// 단계별 모드에서 다음 턴까지의 거리 계산 (GPX + 생성 코스 공통)
  String _distToNextTurn(ModeBNavState navState) {
    if (_modeBTurnPoints.isEmpty) return navState.remainingLabel;
    final pts = _activeNavPts(navState);
    if (pts.isEmpty) return navState.remainingLabel;
    final nearestIdx = _activeNearestIdx(navState);
    final nextTurnGpxIdx = _getNextTurnGpxIdx(nearestIdx);
    if (nextTurnGpxIdx < 0) return navState.remainingLabel;

    final endIdx = nextTurnGpxIdx.clamp(0, pts.length - 1);
    double dist = 0;
    for (int i = nearestIdx; i < endIdx && i < pts.length - 1; i++) {
      dist += _fastDistM(
        pts[i].lat,
        pts[i].lng,
        pts[i + 1].lat,
        pts[i + 1].lng,
      );
    }
    return dist < 1000
        ? '${dist.round()}m'
        : '${(dist / 1000).toStringAsFixed(1)}km';
  }

  /// 현재 위치 기준 다음 턴 포인트 (GPX + 생성 코스 공통)
  TurnPoint? _currentTurnPoint(ModeBNavState navState) {
    final nearestIdx = _activeNearestIdx(navState);
    for (final t in _modeBTurnPoints) {
      if (t.ptIdx > nearestIdx) return t;
    }
    return _modeBTurnPoints.isNotEmpty ? _modeBTurnPoints.last : null;
  }

  // ── 카메라 팔로우 ──────────────────────────────────────────────

  double _calcModeBBearing(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) => bearingDeg(lat1, lng1, lat2, lng2);

  Future<void> _followModeBCamera(
    double lat,
    double lng,
    double bearing,
  ) async {
    if (!_modeBNavCameraFollow || _ctrl == null) return;
    _modeBNavCameraUpdating = true;
    final update =
        NCameraUpdate.withParams(
          target: NLatLng(lat, lng),
          zoom: 17,
          bearing: bearing,
          tilt: 40,
        )..setAnimation(
          animation: NCameraAnimation.linear,
          duration: const Duration(milliseconds: 700),
        );
    await _ctrl!.updateCamera(update);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _modeBNavCameraUpdating = false;
    });
  }

  Future<void> _panToWaypoint(int idx, List<SpotWaypoint> waypoints) async {
    final ctrl = _ctrl;
    if (ctrl == null || idx < 0 || idx >= waypoints.length) return;
    final wp = waypoints[idx];
    _modeBNavCameraUpdating = true;
    await ctrl.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(wp.lat, wp.lng), zoom: 17)
        ..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        ),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _modeBNavCameraUpdating = false;
    });
  }

  void _recenterModeBNav() {
    if (!mounted) return;
    setState(() => _modeBNavCameraFollow = true);
    final pos = _position;
    if (pos != null) {
      final bearing = _modeBNorthUpMode ? 0.0 : _compassHeading;
      _followModeBCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  // ── 도착 감지 ─────────────────────────────────────────────────

  Future<void> _checkModeBNavArrival(ModeBNavState navState) async {
    if (_arrivalHandled) return;
    if (!navState.isNavigating) return;
    final route = navState.route;
    if (route == null) return;

    final isArrived = route.isGenerated
        ? navState.currentWaypointIdx >= route.waypoints.length
        : navState.remainingDistanceM < 50;

    if (isArrived) {
      _arrivalHandled = true;
      // stop() 전에 표시용 데이터 캡처 — stop()이 state를 ModeBNavState()로 리셋하므로
      final arrivedNavState = navState;
      await _saveModeBRecord(navState);
      // 수동 종료·뒤로가기 종료와 동일한 정리(폴리라인·턴 마커·오버레이 삭제)를 거친다 —
      // 과거엔 여기서 provider.stop()만 호출해 도착 후에도 지도에 경로선이 남아있었다.
      await _resetModeBNavState(alreadySaved: true);
      if (mounted) _restoreModeBExploreMarkersIfAny();
      _showModeBNavArrivalMessage(route.name, arrivedNavState);
    }
  }

  void _showModeBNavArrivalMessage(String routeName, ModeBNavState navState) {
    if (!mounted) return;
    final kcal = navState.elapsedKcal.toInt();
    final distKm = (navState.route?.distanceKm ?? 0.0) * navState.kcalProgress;
    final route = navState.route;
    final spotCount =
        route?.waypoints.where((w) => w.type != '출발지').length ?? 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: kMapPanel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉',
                style: AppTypography.displayXl.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$routeName\n완료!',
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ArrivalStatChip(
                    icon: Icons.local_fire_department_rounded,
                    value: '${kcal}kcal',
                    color: context.colors.primary,
                  ),
                  _ArrivalStatChip(
                    icon: Icons.straighten_rounded,
                    value: '${distKm.toStringAsFixed(1)}km',
                    color: context.colors.pinUser,
                  ),
                  if (spotCount > 0)
                    _ArrivalStatChip(
                      icon: Icons.place_rounded,
                      value: '스팟 $spotCount곳',
                      color: context.colors.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.pinUser,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '확인',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneratedOffRouteDialog(
    Position p,
    TouristRouteEntity route,
    int wpIdx,
  ) {
    if (!mounted) return;
    // 중복 다이얼로그 방지
    _offRouteStartTime = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: context.colors.warn,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              '경로 이탈',
              style: AppTypography.bodyLg.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          '현재 경로에서 벗어났어요.\n새로운 경로를 찾을까요?',
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w400,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '현재 경로 유지',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_rerouteGeneratedCourse(p, route, wpIdx));
            },
            child: Text(
              '재경로',
              style: TextStyle(
                color: context.colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 안내 중 뒤로가기(하드웨어/제스처) 시 확인. true = 안내 종료 후 화면 이탈 동의.
  Future<bool> _showModeBExitNavConfirmDialog() async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: context.colors.warn,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              '안내 종료',
              style: AppTypography.bodyLg.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          '진행 중인 코스 안내가 종료됩니다.\n안내를 종료하시겠습니까?',
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
              '계속 안내받기',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '종료',
              style: TextStyle(
                color: context.colors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _navigateToSpotFromWaypoint(SpotWaypoint wp) {
    if (!mounted) return;
    final spot = SpotEntity(
      id: 'nav_${wp.name}_${wp.lat}_${wp.lng}',
      name: wp.name,
      lat: wp.lat,
      lng: wp.lng,
      type: wp.type ?? 'tourist_sight',
      source: 'tour_api',
    );
    context.push('/spot-detail', extra: spot);
  }

  // ── 완주 기록 저장 ────────────────────────────────────────────

  Future<void> _saveModeBRecord(ModeBNavState navState) async {
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      final kcal = navState.elapsedKcal;
      if (kcal < 1.0) return;
      final distM = navState.route != null
          ? (navState.route!.distanceKm * 1000 * navState.kcalProgress)
          : 0.0;
      final date = DateTime.now().toIso8601String().substring(0, 10);
      await ref
          .read(recordRepositoryProvider)
          .addModeBCalories(uid, date, kcal, distM);
      ref.invalidate(weekRecordsProvider);
    } catch (_) {}
  }

  // ── 경로 이탈 스낵바 ─────────────────────────────────────────

  void _showModeBOffRouteSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colors.warn,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              '경로에서 벗어났어요. 경로로 돌아오세요.',
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GPX 재로드 (앱 재시작 후 복원) ───────────────────────────

  Future<void> _reloadGpxForNavigation(String gpxUrl) async {
    if (!mounted) return;
    setState(() => _modeBNavCameraFollow = true);
    try {
      final points = await _fetchGpxPoints(gpxUrl);
      if (!mounted || points.isEmpty) return;
      final pts = points
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList();
      ref.read(modeBNavProvider.notifier).setGpxPoints(pts);

      // 턴 마커 복원 — 정상 시작 흐름과 동일하게 전체 트랙 기준으로 계산해 그린다.
      _modeBTurnPoints = computeTurnPoints(pts);
      _allRouteTurnMarkers = List.of(_modeBTurnPoints);
      if (mounted) unawaited(_drawTurnMarkersOnMap(_allRouteTurnMarkers));

      final pos = _position;
      if (pos != null) {
        await _followModeBCamera(pos.latitude, pos.longitude, 0);
      }
    } catch (_) {}
  }

  // ── 카메라 움직임 감지 ────────────────────────────────────────

  void _onModeBNavCameraGesture() {
    if (!mounted || _modeBNavCameraUpdating) return;
    if (ref.read(modeBNavProvider).isNavigating && _modeBNavCameraFollow) {
      setState(() => _modeBNavCameraFollow = false);
    }
  }

  // ── Overlay widgets ───────────────────────────────────────────

  List<Widget> _buildModeBNavOverlays(
    BuildContext context,
    ModeBNavState navState,
    double bottomPad,
  ) {
    if (!navState.isNavigating || navState.route == null) return const [];

    final route = navState.route!;

    // 단계별 모드용 현재 턴 정보 계산 (GPX + 생성 코스 공통)
    final bool hasRealTurns = _modeBTurnPoints.any(
      (t) => t.type != TurnType.arrival,
    );
    final TurnType curTurnType;
    final String curTurnInstruction;
    final String distToTurn;
    if (_modeBNavStepMode && hasRealTurns) {
      final tp = _currentTurnPoint(navState);
      curTurnType = tp?.type ?? TurnType.straight;
      curTurnInstruction = tp?.instruction ?? '경로를 따라 이동하세요';
      distToTurn = _distToNextTurn(navState);
    } else {
      curTurnType = TurnType.straight;
      curTurnInstruction = '';
      distToTurn = '';
    }

    return [
      // 상단 카드 / 스팟 캐러셀 / 단계별 안내 카드
      Positioned(
        top: MediaQuery.paddingOf(context).top + 8,
        left: 12,
        right: 12,
        child: route.isGenerated && route.waypoints.isNotEmpty
            ? (_modeBNavStepMode
                  ? _ModeBTurnBar(
                      turnType: curTurnType,
                      distanceLabel: distToTurn,
                      instruction: curTurnInstruction,
                      navState: navState,
                      onOverview: _toggleNavStepMode,
                    )
                  : _ModeBNavSpotCarousel(
                      waypoints: route.waypoints,
                      activeIdx: _modeBNavWaypointPageIdx,
                      navState: navState,
                      onPageChanged: (idx) {
                        setState(() {
                          _modeBNavWaypointPageIdx = idx;
                          _modeBNavCameraFollow = false;
                        });
                        _panToWaypoint(idx, route.waypoints);
                      },
                      onStepMode: hasRealTurns ? _toggleNavStepMode : null,
                      showAllSegments: _modeBShowAllSegments,
                      onShowAllToggle: () =>
                          _toggleShowAllSegments(navState.currentWaypointIdx),
                      onSpotTap: _navigateToSpotFromWaypoint,
                    ))
            : (_modeBNavStepMode
                  ? _ModeBTurnBar(
                      turnType: curTurnType,
                      distanceLabel: distToTurn,
                      instruction: curTurnInstruction,
                      navState: navState,
                      onOverview: _toggleNavStepMode,
                    )
                  : _ModeBNavTopCard(
                      navState: navState,
                      onStepMode: hasRealTurns ? _toggleNavStepMode : null,
                    )),
      ),

      // 하단 스트립
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _ModeBNavBottomStrip(
          navState: navState,
          onStop: _stopModeBNavigation,
        ),
      ),
    ];
  }

  // ── Mode B 네비 플로팅 버튼 (줌 컨트롤 위에 렌더링해야 클릭 가능) ──────

  /// build()에서 _buildZoomControls 이후에 호출해야 줌 컨트롤에 가려지지 않음.
  /// 호출 전에 isNavigating 확인 필요.
  List<Widget> _buildModeBNavFloatingButtons(double bottomPad) {
    return [
      // 나침반 버튼 (탭하면 north-up / heading-up 전환)
      Positioned(
        right: 12,
        bottom: 96 + bottomPad + 16 + 56,
        child: GestureDetector(
          onTap: _toggleNorthUpMode,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _modeBNorthUpMode ? context.colors.pinUser : kMapPanel,
              shape: BoxShape.circle,
              border: Border.all(
                color: _modeBNorthUpMode
                    ? context.colors.pinUser
                    : Colors.white24,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: _modeBNorthUpMode
                    ? 0
                    : -_modeBNavLastBearing * (pi / 180),
                child: Icon(
                  Icons.navigation_rounded,
                  size: 22,
                  color: _modeBNorthUpMode ? Colors.white : kMapWhite87,
                ),
              ),
            ),
          ),
        ),
      ),
      // 재센터 버튼
      if (!_modeBNavCameraFollow)
        Positioned(
          right: 12,
          bottom: 96 + bottomPad + 16,
          child: GestureDetector(
            onTap: _recenterModeBNav,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.pinUser,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
    ];
  }
}
