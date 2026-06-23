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

  /// 경로에서 추출한 방향 전환 포인트 목록 (GPX 또는 생성 코스 도로 경로)
  List<_TurnPoint> _modeBTurnPoints = [];

  /// 단계별 세그먼트 폴리라인 마지막 갱신 시각 (스로틀)
  DateTime? _lastStepSegmentUpdate;

  /// 현재 구간 도로 경로 상의 현재 위치 인덱스 (단계별 모드용)
  int _modeBRoadNearestPtIdx = 0;

  /// 네비게이션 시작 이후 누적 이동 거리 (자동 단계별 전환 트리거)
  double _movedSinceNavStart = 0.0;

  /// 도착 처리 중복 방지 플래그 (Bug 1)
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
      Position p, TouristRouteEntity route, int wpIdx);
  Future<void> _drawTurnMarkersOnMap(List<_TurnPoint> turns);
  Future<void> _drawNavSpotMarkers(List<SpotWaypoint> waypoints, {required int currentIdx});
  void _clearNavPolylineCache();

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

    await ref.read(modeBNavProvider.notifier).start(
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
        _movedSinceNavStart = 0.0;
        _arrivalHandled = false; // Bug 1: 세션마다 초기화
      });
    }

    // 방향 전환 포인트 계산 — GPX 코스: 전체, 생성 코스: 첫 번째 구간
    if (!route.isGenerated && gpxPoints.isNotEmpty) {
      final pts = gpxPoints
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList();
      _modeBTurnPoints = _computeTurnPoints(pts);
    } else if (route.isGenerated && _segmentPolylines.isNotEmpty) {
      final firstSeg = _segmentPolylines[0];
      if (firstSeg.isNotEmpty) {
        final pts = firstSeg.map((p) => (lat: p.latitude, lng: p.longitude)).toList();
        _modeBTurnPoints = _computeTurnPoints(pts);
      } else {
        _modeBTurnPoints = [];
      }
      _modeBRoadNearestPtIdx = 0;
    } else {
      _modeBTurnPoints = [];
    }
    // 실제 교차로 turn 포인트가 있을 때만 맵에 마커 그리기
    if (_modeBTurnPoints.any((t) => t.type != _TurnType.arrival) && mounted) {
      unawaited(_drawTurnMarkersOnMap(_modeBTurnPoints));
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

  Future<void> _stopModeBNavigation() async {
    final navState = ref.read(modeBNavProvider);
    if (navState.isNavigating && navState.elapsedKcal >= 1.0) {
      await _saveModeBRecord(navState);
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
      _lastStepSegmentUpdate = null;
      _modeBRoadNearestPtIdx = 0;
    });

    _arrivalHandled = false; // Bug 1: 수동 종료 시 초기화
    _clearNavPolylineCache();

    // 카메라 초기화
    final pos = _position;
    if (_ctrl != null && pos != null) {
      await _ctrl!.updateCamera(
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

    // 종료 후 화면 처리: 음식이 없으면 (앱 재시작 복원 케이스) mode-b 선택으로
    if (!mounted) return;
    final food = ref.read(selectedFoodProvider);
    if (food == null) {
      context.go('/mode-b'); // ignore: use_build_context_synchronously
    }
    // food가 있으면 mode_b 탐색 화면 자동 복귀 (BottomPanel 표시)
  }

  // ── GPS 위치 업데이트 처리 ─────────────────────────────────────

  void _onModeBNavPositionUpdate(Position p, ModeBNavState navState) {
    if (!navState.isNavigating) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    final weightKg = profile?.weightKg ?? AppConstants.defaultWeightKg;
    final transport = navState.route?.type == '자전거' ? 'bike' : 'walk';

    final prevWpIdx = navState.currentWaypointIdx;
    ref.read(modeBNavProvider.notifier).onPositionUpdate(
          p.latitude, p.longitude, weightKg, transport);
    final updatedState = ref.read(modeBNavProvider);
    final newWpIdx = updatedState.currentWaypointIdx;

    // 이동 방향 계산 (GPS 기반)
    final prev = _modeBNavPrevPosition;
    double movedNow = 0.0;
    if (prev != null) {
      final bearing = _calcModeBBearing(
          prev.latitude, prev.longitude, p.latitude, p.longitude);
      movedNow = Geolocator.distanceBetween(
          prev.latitude, prev.longitude, p.latitude, p.longitude);
      if (movedNow >= 2.0) _modeBNavLastBearing = bearing;
    }
    _modeBNavPrevPosition = p;

    if (_modeBNavCameraFollow) {
      final cameraBearing = _modeBNorthUpMode ? 0.0 : _compassHeading;
      _followModeBCamera(p.latitude, p.longitude, cameraBearing);
    }

    // 생성 코스: 현재 구간 내 위치 인덱스 갱신
    if ((navState.route?.isGenerated ?? false) && _segmentPolylines.isNotEmpty) {
      _updateRoadNearestPtIdx(p.latitude, p.longitude, newWpIdx);
    }

    // 자동 단계별 전환: 생성 코스에서 50m 이동 시
    if (!_modeBNavStepMode && (navState.route?.isGenerated ?? false)) {
      if (movedNow >= 2.0) {
        _movedSinceNavStart += movedNow;
        if (_movedSinceNavStart >= 50.0) {
          final hasRealTurns =
              _modeBTurnPoints.any((t) => t.type != _TurnType.arrival);
          if (hasRealTurns && mounted) {
            setState(() => _modeBNavStepMode = true);
          }
        }
      }
    }

    // 단계별 모드: GPX 코스 전용 세그먼트 갱신
    if (_modeBNavStepMode && !((navState.route?.isGenerated) ?? false) &&
        _modeBTurnPoints.any((t) => t.type != _TurnType.arrival)) {
      unawaited(_updateStepModeSegment(updatedState));
    }

    // 생성 코스: 다음 waypoint 도착 감지 → 구간 교체
    if ((navState.route?.isGenerated ?? false) && newWpIdx != prevWpIdx) {
      unawaited(_onGeneratedCourseWaypointAdvanced(
          updatedState.route!, newWpIdx));
    }

    // GPX 코스 이탈 감지 → 이탈 전환 시점에 스낵바 (폴리라인 색상은 trim에서 처리)
    if (!(navState.route?.isGenerated ?? true) &&
        !navState.isOffRoute &&
        updatedState.isOffRoute) {
      _showModeBOffRouteSnackBar();
    }

    // 생성 코스 이탈 감지 → 30초 유지 시 자동 재경로
    final route = navState.route;
    if (route != null && route.isGenerated && _segmentPolylines.isNotEmpty) {
      final currentIdx =
          navState.currentWaypointIdx.clamp(0, _segmentPolylines.length - 1);
      final pts = _segmentPolylines[currentIdx];
      if (pts.isNotEmpty) {
        double minDist = double.infinity;
        for (var i = 0; i < pts.length; i++) { // Bug 7: 전체 포인트 검사
          final d = Geolocator.distanceBetween(
              p.latitude, p.longitude, pts[i].latitude, pts[i].longitude);
          if (d < minDist) minDist = d;
          if (minDist < 20) break; // 충분히 가까우면 조기 종료
        }
        if (minDist > 100) {
          _offRouteStartTime ??= DateTime.now();
          if (DateTime.now().difference(_offRouteStartTime!).inSeconds >= 30) {
            _offRouteStartTime = null;
            _showGeneratedOffRouteDialog(p, route, navState.currentWaypointIdx);
          }
        } else {
          _offRouteStartTime = null;
        }
      }
    }
  }

  // 생성 코스 waypoint 진행 시 호출 — 구간 교체 + 턴 포인트 재계산
  Future<void> _onGeneratedCourseWaypointAdvanced(
      TouristRouteEntity route, int newWpIdx) async {
    if (!mounted) return;
    if (newWpIdx >= route.waypoints.length) return;

    // 폴리라인 교체
    await _drawSegmentsOnMap(newWpIdx, showAll: _modeBShowAllSegments);

    // 새 구간의 턴 포인트 계산
    if (newWpIdx < _segmentPolylines.length) {
      final seg = _segmentPolylines[newWpIdx];
      if (seg.isNotEmpty) {
        final pts = seg.map((p) => (lat: p.latitude, lng: p.longitude)).toList();
        _modeBTurnPoints = _computeTurnPoints(pts);
      } else {
        _modeBTurnPoints = [];
      }
    }
    _modeBRoadNearestPtIdx = 0;

    // 단계별 모드 중이면 턴 마커 갱신
    if (_modeBTurnPoints.any((t) => t.type != _TurnType.arrival) && mounted) {
      unawaited(_drawTurnMarkersOnMap(_modeBTurnPoints));
    }
    // Bug 5: nav spot 마커는 modeBNavProvider listener에서 처리 — 중복 호출 제거
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
      await _drawSegmentsOnMap(navState.currentWaypointIdx,
          showAll: _modeBShowAllSegments);
    } else {
      // GPX 코스: 단계별 ON → step_segment 추가, OFF → 제거하고 route_path 복원
      final ctrl = _ctrl;
      if (ctrl == null) return;

      if (_modeBNavStepMode) {
        unawaited(_updateStepModeSegment(navState));
      } else {
        await ctrl.deleteOverlay(
          NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'step_segment'),
        ).catchError((_) {});
        if (!mounted) return;
        final c = context.colors;
        final pts = navState.gpxPoints;
        final startIdx = navState.nearestGpxPtIdx;
        if (pts.length > startIdx + 1) {
          final remaining =
              pts.sublist(startIdx).map((p) => NLatLng(p.lat, p.lng)).toList();
          final routeColor =
              navState.route?.type == '자전거' ? c.warn : c.primary;
          await ctrl.addOverlay(NPolylineOverlay(
            id: 'route_path',
            coords: remaining,
            color: routeColor,
            width: 5,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          ));
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
    final endIdx = (nextTurnGpxIdx > 0 ? nextTurnGpxIdx : pts.length - 1)
        .clamp(0, pts.length - 1);
    final startIdx = nearestIdx.clamp(0, pts.length - 1);
    if (endIdx - startIdx < 1) return;

    final segment = pts
        .sublist(startIdx, endIdx + 1)
        .map((p) => NLatLng(p.lat, p.lng))
        .toList();

    // GPX 코스: route_path는 건드리지 않고 step_segment를 위에 덧그림
    await ctrl.deleteOverlay(
      NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'step_segment'),
    ).catchError((_) {});
    if (!mounted) return;

    final c = context.colors;
    final routeColor =
        navState.route?.type == '자전거' ? c.warn : c.primary;
    await ctrl.addOverlay(NPolylineOverlay(
      id: 'step_segment',
      coords: segment,
      color: routeColor,
      width: 6,
      lineCap: NLineCap.round,
      lineJoin: NLineJoin.round,
    ));
  }

  int _getNextTurnGpxIdx(int nearestIdx) {
    for (final t in _modeBTurnPoints) {
      if (t.gpxIdx > nearestIdx) return t.gpxIdx;
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

  /// 현재 구간(_segmentPolylines[currentWpIdx]) 상의 위치 인덱스 갱신.
  void _updateRoadNearestPtIdx(double lat, double lng, int currentWpIdx) {
    if (_segmentPolylines.isEmpty || currentWpIdx >= _segmentPolylines.length) return;
    final pts = _segmentPolylines[currentWpIdx];
    if (pts.isEmpty) return;
    final searchEnd = pts.length.clamp(0, _modeBRoadNearestPtIdx + 200);
    int best = _modeBRoadNearestPtIdx;
    double bestDist = double.infinity;
    for (int i = _modeBRoadNearestPtIdx; i < searchEnd; i++) {
      final d = _fastDistM(lat, lng, pts[i].latitude, pts[i].longitude);
      if (d < bestDist) { bestDist = d; best = i; }
    }
    if (best > _modeBRoadNearestPtIdx) _modeBRoadNearestPtIdx = best;
  }

  // ── 방향 전환 포인트 계산 ──────────────────────────────────────

  /// GPX 포인트 목록에서 교차로 방향 전환 지점을 추출.
  /// 인덱스 기반이 아닌 실거리(m) 기반 윈도우를 사용해 GPX 밀도에 무관하게 동작.
  List<_TurnPoint> _computeTurnPoints(List<({double lat, double lng})> pts) {
    if (pts.length < 6) return [];

    // 누적 거리(m) 계산 — 고밀도 GPX 포인트이므로 Equirectangular 근사로 충분
    final cumDist = List<double>.filled(pts.length, 0.0);
    for (int i = 1; i < pts.length; i++) {
      cumDist[i] = cumDist[i - 1] +
          _fastDistM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    }

    final totalDist = cumDist.last;
    if (totalDist < 50) return [];

    // 25m 윈도우로 접근/이탈 방향 비교, 40m 간격 유지
    const segLen = 25.0;
    const turnThreshold = 25.0;
    const uTurnThreshold = 120.0;
    const minDistSpacing = 40.0;

    final turns = <_TurnPoint>[];
    double lastTurnDist = -minDistSpacing;

    for (int i = 0; i < pts.length; i++) {
      final d = cumDist[i];
      if (d < segLen || d > totalDist - segLen) continue;

      // 접근 기준점: 현재보다 segLen 뒤
      int iA = i;
      while (iA > 0 && cumDist[iA] > d - segLen) { iA--; }
      // 이탈 기준점: 현재보다 segLen 앞
      int iL = i;
      while (iL < pts.length - 1 && cumDist[iL] < d + segLen) { iL++; }

      if (iA == i || iL == i) continue;

      final approachBearing = _calcModeBBearing(
          pts[iA].lat, pts[iA].lng, pts[i].lat, pts[i].lng);
      final leaveBearing = _calcModeBBearing(
          pts[i].lat, pts[i].lng, pts[iL].lat, pts[iL].lng);

      double delta = leaveBearing - approachBearing;
      while (delta > 180) { delta -= 360; }
      while (delta < -180) { delta += 360; }
      final absD = delta.abs();

      if (absD > turnThreshold && d - lastTurnDist >= minDistSpacing) {
        final type = absD >= uTurnThreshold
            ? _TurnType.uTurn
            : delta > 0
                ? _TurnType.right
                : _TurnType.left;
        final instruction = absD >= uTurnThreshold
            ? '유턴하세요'
            : delta > 0
                ? '오른쪽 길로 계속 진행'
                : '왼쪽 길로 계속 진행';

        turns.add(_TurnPoint(
          type: type,
          gpxIdx: i,
          lat: pts[i].lat,
          lng: pts[i].lng,
          instruction: instruction,
        ));
        lastTurnDist = d;
      }
    }

    // 도착 포인트
    turns.add(_TurnPoint(
      type: _TurnType.arrival,
      gpxIdx: pts.length - 1,
      lat: pts.last.lat,
      lng: pts.last.lng,
      instruction: '목적지에 도착합니다',
    ));

    debugPrint('[TurnDetect] pts=${pts.length} totalDist=${totalDist.round()}m turns=${turns.length - 1}');
    return turns;
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
      dist += _fastDistM(pts[i].lat, pts[i].lng, pts[i + 1].lat, pts[i + 1].lng);
    }
    return dist < 1000 ? '${dist.round()}m' : '${(dist / 1000).toStringAsFixed(1)}km';
  }

  /// 현재 위치 기준 다음 턴 포인트 (GPX + 생성 코스 공통)
  _TurnPoint? _currentTurnPoint(ModeBNavState navState) {
    final nearestIdx = _activeNearestIdx(navState);
    for (final t in _modeBTurnPoints) {
      if (t.gpxIdx > nearestIdx) return t;
    }
    return _modeBTurnPoints.isNotEmpty ? _modeBTurnPoints.last : null;
  }

  // ── 카메라 팔로우 ──────────────────────────────────────────────

  double _calcModeBBearing(double lat1, double lng1, double lat2, double lng2) =>
      _bearingDeg(lat1, lng1, lat2, lng2);

  Future<void> _followModeBCamera(double lat, double lng, double bearing) async {
    if (!_modeBNavCameraFollow || _ctrl == null) return;
    _modeBNavCameraUpdating = true;
    final update = NCameraUpdate.withParams(
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
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(wp.lat, wp.lng),
        zoom: 17,
      )..setAnimation(
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
    if (_arrivalHandled) return; // Bug 1: 중복 저장 방지
    if (!navState.isNavigating) return;
    final route = navState.route;
    if (route == null) return;

    final isArrived = route.isGenerated
        ? navState.currentWaypointIdx >= route.waypoints.length
        : navState.remainingDistanceM < 50;

    if (isArrived) {
      _arrivalHandled = true; // Bug 1: 플래그 먼저 세트
      await _saveModeBRecord(navState);
      // stop() 전에 표시용 데이터 캡처 — stop()이 state를 ModeBNavState()로 리셋하므로
      final arrivedNavState = navState;
      ref.read(modeBNavProvider.notifier).stop();
      _resetModeBNavCamera();
      _showModeBNavArrivalMessage(route.name, arrivedNavState);
    }
  }

  Future<void> _resetModeBNavCamera() async {
    if (_ctrl == null || _position == null) return;
    setState(() {
      _modeBNavCameraFollow = true;
      _modeBNavCameraUpdating = false;
      _modeBNavLastBearing = 0.0;
      _modeBNavPrevPosition = null;
    });
    await _ctrl!.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(_position!.latitude, _position!.longitude),
        zoom: 15,
        bearing: 0,
        tilt: 0,
      )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 600),
        ),
    );
  }

  void _showModeBNavArrivalMessage(String routeName, ModeBNavState navState) {
    if (!mounted) return;
    final kcal = navState.elapsedKcal.toInt();
    final distKm = (navState.route?.distanceKm ?? 0.0) * navState.kcalProgress;
    final route = navState.route;
    final spotCount = route?.waypoints.where((w) => w.type != '출발지').length ?? 0;

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
              const Text('🎉', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                '$routeName\n완료!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _ArrivalStatChip(
                    icon: Icons.local_fire_department_rounded,
                    value: '${kcal}kcal',
                    color: context.colors.primary),
                _ArrivalStatChip(
                    icon: Icons.straighten_rounded,
                    value: '${distKm.toStringAsFixed(1)}km',
                    color: context.colors.pinUser),
                if (spotCount > 0)
                  _ArrivalStatChip(
                      icon: Icons.place_rounded,
                      value: '스팟 $spotCount곳',
                      color: context.colors.secondary),
              ]),
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
                  child: const Text('확인',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneratedOffRouteDialog(Position p, TouristRouteEntity route, int wpIdx) {
    if (!mounted) return;
    // 중복 다이얼로그 방지
    _offRouteStartTime = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: context.colors.warn, size: 22),
          const SizedBox(width: 8),
          const Text('경로 이탈',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          '현재 경로에서 벗어났어요.\n새로운 경로를 찾을까요?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('현재 경로 유지',
                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_rerouteGeneratedCourse(p, route, wpIdx));
            },
            child: Text('재경로',
                style: TextStyle(
                    color: context.colors.pinUser, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
      await ref.read(recordRepositoryProvider).addModeBCalories(uid, date, kcal, distM);
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
        content: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('경로에서 벗어났어요. 경로로 돌아오세요.',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
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
      ref.read(modeBNavProvider.notifier).setGpxPoints(
            points.map((p) => (lat: p.latitude, lng: p.longitude)).toList());

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
    final bool hasRealTurns = _modeBTurnPoints.any((t) => t.type != _TurnType.arrival);
    final _TurnType curTurnType;
    final String curTurnInstruction;
    final String distToTurn;
    if (_modeBNavStepMode && hasRealTurns) {
      final tp = _currentTurnPoint(navState);
      curTurnType = tp?.type ?? _TurnType.straight;
      curTurnInstruction = tp?.instruction ?? '경로를 따라 이동하세요';
      distToTurn = _distToNextTurn(navState);
    } else {
      curTurnType = _TurnType.straight;
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
                    onShowAllToggle: () => _toggleShowAllSegments(
                        navState.currentWaypointIdx),
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
                BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
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
                  BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.my_location_rounded, size: 22, color: Colors.white),
            ),
          ),
        ),
    ];
  }
}
