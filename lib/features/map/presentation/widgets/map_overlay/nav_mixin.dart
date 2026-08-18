part of '../map_overlay.dart';

mixin _NavOverlayMixin on ConsumerState<MapOverlay> {
  // ── Navigation state ───────────────────────────────────────────
  bool _navCameraFollow = true;
  bool _navCameraUpdating = false;
  double _lastNavBearing = 0.0;
  Position? _prevNavPosition;

  /// true = 북쪽 고정, false = 이동 방향 (기본, Mode B와 동일)
  bool _modeANorthUpMode = false;

  final _modeARoadRoute = const RoadRouteDatasource();

  // ── 도보/자전거 구간 폴리라인 실시간 트리밍 캐시 (Mode B _trimNavPolylineToRemaining와 동일 패턴) ──
  final Map<int, NPolylineOverlay> _cachedModeASegPolylines = {};
  NPolylineOverlay? _cachedModeASegDonePolyline;
  int _lastTrimModeALegIdx = -1;
  bool _lastTrimModeAOffRoute = false;

  // ── Mode A walk/bike/대중교통(도보구간) 방향 전환 안내 상태 ─────────────────
  /// 현재 구간(leg)의 턴 포인트 — 단계별 안내 카드 텍스트용
  List<TurnPoint> _modeATurnPoints = [];

  /// 코스 전체(모든 구간) 턴 포인트 — 지도 마커용, 지나가면 제거됨
  List<TurnPoint> _allModeATurnMarkers = [];
  final Set<String> _drawnModeATurnMarkerIds = {};
  int _modeARoadNearestPtIdx = 0;
  ({int nearestIdx, double distToRoadM, double remainingSegM})?
  _lastModeARoadProgress;
  DateTime? _modeAOffRouteStartTime;

  /// 도보/자전거 경로 재경로 시 소스 고정 ('tmap' | 'kakao')
  String? _modeARouteSource;

  /// false = 전체 경로(overview), true = 단계별(step-by-step)
  bool _modeANavStepMode = false;
  double _movedSinceModeANavStart = 0.0;

  /// 대중교통 두 단계 모드: false = 전체 경로 개요, true = 단계별 안내
  bool _modeATransitNavStepMode = false;

  NaverMapController? get _ctrl;
  Position? get _position;

  /// 기기 나침반 방위각 (_MapOverlayState._compassHeading으로 구현)
  double get _compassHeading;

  // ── Camera helpers ─────────────────────────────────────────────

  Future<void> _followNavCamera(double lat, double lng, double bearing) async {
    if (!_navCameraFollow || _ctrl == null) return;
    _navCameraUpdating = true;
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
      if (mounted) _navCameraUpdating = false;
    });
  }

  void _clearModeANavCache() {
    _cachedModeASegPolylines.clear();
    _cachedModeASegDonePolyline = null;
    _lastTrimModeALegIdx = -1;
    _lastTrimModeAOffRoute = false;
    _drawnModeATurnMarkerIds.clear();
  }

  void _toggleModeANorthUpMode() {
    if (!mounted) return;
    setState(() => _modeANorthUpMode = !_modeANorthUpMode);
    final pos = _position;
    if (pos != null && _navCameraFollow) {
      final bearing = _modeANorthUpMode ? 0.0 : _lastNavBearing;
      _followNavCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  Future<void> _recenterNav() async {
    if (!mounted) return;
    setState(() => _navCameraFollow = true);
    final pos = _position;
    if (pos != null) {
      final bearing = _modeANorthUpMode ? 0.0 : _compassHeading;
      await _followNavCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  Future<void> _resetNavCamera() async {
    if (_ctrl == null || _position == null) return;
    setState(() {
      _navCameraFollow = true;
      _navCameraUpdating = false;
      _lastNavBearing = 0.0;
      _prevNavPosition = null;
      _modeANorthUpMode = false;
    });
    _clearModeANavCache();
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

  // ── 도로 스냅 진행률 계산 (Mode B _computeGeneratedRoadProgress와 동일 패턴) ──
  // 화면에 그려지는 구간 폴리라인(route.segmentPolylines[legIdx]) 기준으로 최근접점을
  // 찾는다 — provider 갱신·트리밍 색상·이탈/재경로 판정이 모두 이 값을 공유한다.
  ({int nearestIdx, double distToRoadM, double remainingSegM})
  _computeModeARoadProgress(
    double lat,
    double lng,
    RouteResultEntity route,
    int legIdx,
  ) {
    final pts = route.segmentPolylines[legIdx];
    final searchStart = (_modeARoadNearestPtIdx - 30).clamp(0, pts.length - 1);
    final searchEnd = (_modeARoadNearestPtIdx + 200).clamp(0, pts.length);
    int best = _modeARoadNearestPtIdx.clamp(0, pts.length - 1);
    double bestDist = double.infinity;
    for (int i = searchStart; i < searchEnd; i++) {
      final d = _fastDistM(lat, lng, pts[i].latitude, pts[i].longitude);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    _modeARoadNearestPtIdx = best;

    double remainingSegM = 0;
    for (int i = best; i < pts.length - 1; i++) {
      remainingSegM += _fastDistM(
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

  /// GPS 위치 업데이트 핵심 처리 — 도보/자전거 전용 (대중교통은 _onModeATransitPositionUpdate).
  void _onModeAWalkBikePositionUpdate(Position p, RouteResultEntity route) {
    final navState = ref.read(modeANavProvider);
    if (!navState.isNavigating) return;
    if (route.segmentPolylines.isEmpty) return;

    final prevLegIdx = navState.currentLegIdx;
    final legIdx = prevLegIdx.clamp(0, route.segmentPolylines.length - 1);
    final progress = _computeModeARoadProgress(
      p.latitude,
      p.longitude,
      route,
      legIdx,
    );
    _lastModeARoadProgress = progress;

    final legEnd = route.segmentPolylines[legIdx].last;
    final distToLegEndM = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      legEnd.latitude,
      legEnd.longitude,
    );

    ref
        .read(modeANavProvider.notifier)
        .updateFromRoad(
          route: route,
          nearestPtIdx: progress.nearestIdx,
          distToRoadM: progress.distToRoadM,
          distToLegEndM: distToLegEndM,
          remainingSegM: progress.remainingSegM,
        );

    // 실측 GPS 속도 기반 실시간 칼로리 — foreground 걸음 추적·Mode B 내비게이션과
    // 동일한 공식(LiveKcalTracker)을 쓴다.
    final profile = ref.read(userProfileProvider).valueOrNull;
    final metrics = profile?.toBodyMetrics() ?? BodyMetrics.defaultMetrics;
    ref
        .read(modeANavProvider.notifier)
        .updateKcal(lat: p.latitude, lng: p.longitude, metrics: metrics);

    final updatedState = ref.read(modeANavProvider);
    final newLegIdx = updatedState.currentLegIdx;
    final legAdvanced = newLegIdx != prevLegIdx;
    if (legAdvanced) {
      _modeARoadNearestPtIdx = 0;
      _lastModeARoadProgress = null;
      unawaited(_onModeALegAdvanced(route, newLegIdx));
    }

    // 지나온 턴 마커 제거
    final ptIdx = legAdvanced ? -1 : progress.nearestIdx;
    _pruneModeATurnMarkers(currentLegIdx: newLegIdx, currentPtIdx: ptIdx);

    // 이탈 감지 → 30초 유지 시 다이얼로그 + 자동 재경로 (Mode B 생성 코스와 동일)
    if (!legAdvanced) {
      if (progress.distToRoadM > AppConstants.offRouteThresholdM) {
        _modeAOffRouteStartTime ??= DateTime.now();
        if (DateTime.now().difference(_modeAOffRouteStartTime!).inSeconds >=
            30) {
          _modeAOffRouteStartTime = null;
          _showModeAOffRouteDialog(p, route, newLegIdx);
        }
      } else {
        _modeAOffRouteStartTime = null;
      }
    }
  }

  /// 구간 전환 시 호출 — 폴리라인 재표시 + 새 구간 턴 포인트 갱신
  Future<void> _onModeALegAdvanced(
    RouteResultEntity route,
    int newLegIdx,
  ) async {
    if (!mounted) return;
    if (newLegIdx >= route.segmentPolylines.length) return;

    await _drawModeASegmentsOnMap(route, newLegIdx);

    final seg = route.segmentPolylines[newLegIdx];
    _modeATurnPoints = seg.length >= 6
        ? computeTurnPoints(
            seg.map((p) => (lat: p.latitude, lng: p.longitude)).toList(),
            legIdx: newLegIdx,
          )
        : [];
  }

  /// 재경로(reroute) — Mode B `_rerouteGeneratedCourse`와 동일 패턴. 현재 구간만
  /// 다시 요청하고, 확정된 소스(_modeARouteSource)를 그대로 따른다.
  Future<void> _rerouteModeALeg(
    Position p,
    RouteResultEntity route,
    int legIdx,
  ) async {
    if (!mounted || legIdx >= route.segmentPolylines.length) return;
    try {
      final legEnd = route.segmentPolylines[legIdx].last;
      final newPts = await _modeARoadRoute.fetchSingleLeg(
        fromLat: p.latitude,
        fromLng: p.longitude,
        toLat: legEnd.latitude,
        toLng: legEnd.longitude,
        preferredSource: _modeARouteSource,
      );
      if (!mounted || newPts.length < 2) return;

      final newSeg = newPts
          .map((pt) => LatLng(latitude: pt.lat, longitude: pt.lng))
          .toList();
      route.segmentPolylines[legIdx] = newSeg;

      await _drawModeASegmentsOnMap(route, legIdx);

      final newTurns = computeTurnPoints(
        newSeg.map((pt) => (lat: pt.latitude, lng: pt.longitude)).toList(),
        legIdx: legIdx,
      );
      _modeATurnPoints = newTurns;
      _modeARoadNearestPtIdx = 0;
      _lastModeARoadProgress = null;

      _allModeATurnMarkers = [
        ..._allModeATurnMarkers.where((t) => t.legIdx != legIdx),
        ...newTurns,
      ];
      if (mounted) unawaited(_drawModeATurnMarkers(_allModeATurnMarkers));
    } catch (_) {}
  }

  void _showModeAOffRouteDialog(
    Position p,
    RouteResultEntity route,
    int legIdx,
  ) {
    if (!mounted) return;
    _modeAOffRouteStartTime = null;
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
              unawaited(_rerouteModeALeg(p, route, legIdx));
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
  /// Mode B의 _showModeBExitNavConfirmDialog와 동일한 패턴.
  Future<bool> _showModeAExitNavConfirmDialog() async {
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
          '진행 중인 경로 안내가 종료됩니다.\n안내를 종료하시겠습니까?',
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

  /// 대중교통 도보 구간 이탈 — Mode B GPX 코스와 동일하게 스낵바만(자동 재경로 없음).
  void _showModeAOffRouteSnackBar() {
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

  // ── 대중교통 도보 구간 이탈 감지 ─────────────────────────────────
  // 탑승 구간(버스/지하철)에는 이탈 개념이 없으므로 현재 subPath가 도보일 때만 계산한다.
  void _onModeATransitPositionUpdate(Position p, RouteResultEntity route) {
    final navState = ref.read(modeANavProvider);
    if (!navState.isNavigating) return;
    final steps = route.transitSteps;
    if (steps.isEmpty) return;

    final stepIdx = navState.currentTransitStepIdx.clamp(0, steps.length - 1);
    final step = steps[stepIdx];

    double? distToRoadM;
    if (step.isWalk && step.stepPoints.length >= 2) {
      final searchEnd = (_modeARoadNearestPtIdx + 150).clamp(
        0,
        step.stepPoints.length,
      );
      final start = stepIdx == _lastTrimModeALegIdx
          ? _modeARoadNearestPtIdx.clamp(0, step.stepPoints.length - 1)
          : 0;
      int best = start;
      double bestDist = double.infinity;
      for (int i = start; i < searchEnd; i++) {
        final d = _fastDistM(
          p.latitude,
          p.longitude,
          step.stepPoints[i].latitude,
          step.stepPoints[i].longitude,
        );
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      _modeARoadNearestPtIdx = best;
      distToRoadM = bestDist;
    } else {
      _modeARoadNearestPtIdx = 0;
    }

    ref
        .read(modeANavProvider.notifier)
        .updateTransitStep(
          route: route,
          lat: p.latitude,
          lng: p.longitude,
          distToRoadM: distToRoadM,
        );

    final updated = ref.read(modeANavProvider);
    if (updated.currentTransitStepIdx != stepIdx) {
      _modeARoadNearestPtIdx = 0;
      final newStep =
          steps[updated.currentTransitStepIdx.clamp(0, steps.length - 1)];
      _modeATurnPoints = newStep.isWalk && newStep.stepPoints.length >= 6
          ? computeTurnPoints(
              newStep.stepPoints
                  .map((p) => (lat: p.latitude, lng: p.longitude))
                  .toList(),
              legIdx: updated.currentTransitStepIdx,
            )
          : [];
    }

    _pruneModeATurnMarkers(
      currentLegIdx: updated.currentTransitStepIdx,
      currentPtIdx: updated.currentTransitStepIdx == stepIdx
          ? _modeARoadNearestPtIdx
          : -1,
    );

    // 도보 구간 이탈: 스낵바만 표시(자동 재경로 없음 — 곧 정류장/역에 도착해 구간이
    // 바뀌므로 코스 전체 재탐색이 더 적절하다고 판단). 실제 UI는 map_overlay.dart의
    // ref.listen(modeANavProvider)에서 isOffRoute 전환을 감지해 처리한다.
  }

  // ── Mode A 폴리라인 실시간 트리밍 (Mode B 생성 코스 _trimNavPolylineToRemaining와 동일 패턴) ──
  // delete+add 대신 setCoords/setColor로 채널 메시지를 최소화한다.

  Future<void> _trimModeAPolylineToRemaining(
    Position p,
    ModeANavState navState,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    if (!navState.isNavigating) return;

    final route = ref.read(modeAProvider).routeResult;
    if (route == null || route.transport == 'transit')
      return; // 대중교통은 _trimModeATransitPolylines
    if (route.segmentPolylines.isEmpty) return;

    final progress = _lastModeARoadProgress;
    if (progress == null) return;

    final legIdx = navState.currentLegIdx.clamp(
      0,
      route.segmentPolylines.length - 1,
    );
    final pts = route.segmentPolylines[legIdx];
    if (pts.isEmpty) return;

    final nearestIdx = progress.nearestIdx.clamp(0, pts.length - 1);
    final isOffRoute = navState.isOffRoute;

    if (nearestIdx == _lastTrimModeALegIdx &&
        isOffRoute == _lastTrimModeAOffRoute)
      return;
    if (nearestIdx <= 0) return;
    if (nearestIdx >= pts.length - 1) return;

    final offRouteColor = context.colors.warn;
    final routeColor = context.colors.accent;
    final polylineColor = isOffRoute ? offRouteColor : routeColor;

    final trimmed = pts
        .sublist(nearestIdx)
        .map((pt) => NLatLng(pt.latitude, pt.longitude))
        .toList();
    if (trimmed.length < 2) return;

    final cached = _cachedModeASegPolylines[legIdx];
    if (cached != null) {
      if (nearestIdx != _lastTrimModeALegIdx) cached.setCoords(trimmed);
      if (isOffRoute != _lastTrimModeAOffRoute) cached.setColor(polylineColor);
    } else {
      await ctrl
          .deleteOverlay(
            NOverlayInfo(
              type: NOverlayType.polylineOverlay,
              id: 'ma_seg_$legIdx',
            ),
          )
          .catchError((_) {});
      if (!mounted) return;
      final poly = NPolylineOverlay(
        id: 'ma_seg_$legIdx',
        coords: trimmed,
        color: polylineColor,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      );
      await ctrl.addOverlay(poly);
      if (mounted) _cachedModeASegPolylines[legIdx] = poly;
    }

    if (nearestIdx != _lastTrimModeALegIdx) {
      final donePts = pts.sublist(0, nearestIdx + 1);
      if (donePts.length >= 2) {
        final doneCoords = donePts
            .map((pt) => NLatLng(pt.latitude, pt.longitude))
            .toList();
        final doneCached = _cachedModeASegDonePolyline;
        if (doneCached != null) {
          doneCached.setCoords(doneCoords);
        } else {
          await ctrl
              .deleteOverlay(
                NOverlayInfo(
                  type: NOverlayType.polylineOverlay,
                  id: 'ma_seg_done_$legIdx',
                ),
              )
              .catchError((_) {});
          if (!mounted) return;
          final donePoly = NPolylineOverlay(
            id: 'ma_seg_done_$legIdx',
            coords: doneCoords,
            color: kMapWhite45,
            width: 4,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          );
          await ctrl.addOverlay(donePoly);
          if (mounted) _cachedModeASegDonePolyline = donePoly;
        }
      }
    }

    _lastTrimModeALegIdx = nearestIdx;
    _lastTrimModeAOffRoute = isOffRoute;
  }

  /// 구간별 폴리라인 그리기 (내비 시작·구간 전환·재경로 시 호출)
  Future<void> _drawModeASegmentsOnMap(
    RouteResultEntity route,
    int currentLegIdx,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted || route.segmentPolylines.isEmpty) return;

    final accentColor = context.colors.accent;

    _cachedModeASegPolylines.clear();
    _cachedModeASegDonePolyline = null;
    _lastTrimModeALegIdx = -1;
    _lastTrimModeAOffRoute = false;

    // 프리뷰 폴리라인(검색 결과 화면에서 그려진 mode_a_route) 제거 — 내비 시작 후엔
    // 구간별(ma_seg_$i) 폴리라인이 그 역할을 대신한다.
    await ctrl
        .deleteOverlay(
          const NOverlayInfo(
            type: NOverlayType.polylineOverlay,
            id: 'mode_a_route',
          ),
        )
        .catchError((_) {});

    for (var i = 0; i < route.segmentPolylines.length; i++) {
      await ctrl
          .deleteOverlay(
            NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'ma_seg_$i'),
          )
          .catchError((_) {});
      await ctrl
          .deleteOverlay(
            NOverlayInfo(
              type: NOverlayType.polylineOverlay,
              id: 'ma_seg_done_$i',
            ),
          )
          .catchError((_) {});
    }
    if (!mounted) return;

    final idx = currentLegIdx.clamp(0, route.segmentPolylines.length - 1);
    final pts = route.segmentPolylines[idx]
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();
    if (pts.length >= 2) {
      final poly = NPolylineOverlay(
        id: 'ma_seg_$idx',
        coords: pts,
        color: accentColor,
        width: 5,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      );
      await ctrl.addOverlay(poly);
      if (mounted) _cachedModeASegPolylines[idx] = poly;
    }
  }

  // ── Mode A 네비 플로팅 버튼 (나침반 토글 + 재센터, Mode B와 동일 레이아웃) ──

  List<Widget> _buildModeANavFloatingButtons(double bottomPad) {
    return [
      // 나침반 버튼 (탭하면 north-up / heading-up 전환)
      Positioned(
        right: 12,
        bottom: 96 + bottomPad + 16 + 56,
        child: GestureDetector(
          onTap: _toggleModeANorthUpMode,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _modeANorthUpMode ? context.colors.pinUser : kMapPanel,
              shape: BoxShape.circle,
              border: Border.all(
                color: _modeANorthUpMode
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
                angle: _modeANorthUpMode ? 0 : -_lastNavBearing * (pi / 180),
                child: Icon(
                  Icons.navigation_rounded,
                  size: 22,
                  color: _modeANorthUpMode ? Colors.white : kMapWhite87,
                ),
              ),
            ),
          ),
        ),
      ),
      // 재센터 버튼 (카메라 팔로우 해제 시)
      if (!_navCameraFollow)
        Positioned(
          right: 12,
          bottom: 96 + bottomPad + 16,
          child: GestureDetector(
            onTap: _recenterNav,
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

  // ── Mode A 방향 전환 포인트 초기화·조회·마커 관리 ─────────────────────────
  // 턴 감지 알고리즘(computeTurnPoints)과 타입(TurnPoint/TurnType)은
  // core/utils/turn_point_utils.dart의 공용 구현 — Mode B도 동일하게 재사용한다.

  void _initModeATurnPoints(RouteResultEntity route) {
    final all = <TurnPoint>[];
    if (route.transport == 'transit') {
      for (int i = 0; i < route.transitSteps.length; i++) {
        final step = route.transitSteps[i];
        if (!step.isWalk || step.stepPoints.length < 6) continue;
        final pts = step.stepPoints
            .map((p) => (lat: p.latitude, lng: p.longitude))
            .toList();
        all.addAll(computeTurnPoints(pts, legIdx: i));
      }
    } else {
      for (int i = 0; i < route.segmentPolylines.length; i++) {
        final seg = route.segmentPolylines[i];
        if (seg.length < 6) continue;
        final pts = seg
            .map((p) => (lat: p.latitude, lng: p.longitude))
            .toList();
        all.addAll(computeTurnPoints(pts, legIdx: i));
      }
    }
    _allModeATurnMarkers = all;
    _modeATurnPoints = all.where((t) => t.legIdx == 0).toList();
    _modeARoadNearestPtIdx = 0;
    _lastModeARoadProgress = null;
    _modeARouteSource = route.routeSource;

    final legCount = route.transport == 'transit'
        ? route.transitSteps.length
        : route.segmentPolylines.length;
    debugPrint(
      '[ModeA TurnDetect] transport=${route.transport} legs=$legCount '
      'turns=${all.where((t) => t.type != TurnType.arrival).length} total=${all.length}',
    );
  }

  TurnPoint? _getModeACurrentTurn() {
    for (final t in _modeATurnPoints) {
      if (t.ptIdx > _modeARoadNearestPtIdx) return t;
    }
    return _modeATurnPoints.isNotEmpty ? _modeATurnPoints.last : null;
  }

  String _getModeADistToNextTurnLabel(List<LatLng> pts) {
    if (_modeATurnPoints.isEmpty || pts.isEmpty) return '';
    final nextTurn = _getModeACurrentTurn();
    if (nextTurn == null) return '';
    final endIdx = nextTurn.ptIdx.clamp(0, pts.length - 1);
    var dist = 0.0;
    for (
      int i = _modeARoadNearestPtIdx;
      i < endIdx && i < pts.length - 1;
      i++
    ) {
      dist += _fastDistM(
        pts[i].latitude,
        pts[i].longitude,
        pts[i + 1].latitude,
        pts[i + 1].longitude,
      );
    }
    return dist < 1000
        ? '${dist.round()}m'
        : '${(dist / 1000).toStringAsFixed(1)}km';
  }

  /// 사용자가 지나온 턴 마커를 목록·지도에서 제거한다 (Mode B `_pruneRouteTurnMarkers`와 동일).
  void _pruneModeATurnMarkers({
    required int currentLegIdx,
    required int currentPtIdx,
  }) {
    if (_allModeATurnMarkers.isEmpty) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;

    final remaining = <TurnPoint>[];
    for (final t in _allModeATurnMarkers) {
      final passed =
          t.legIdx < currentLegIdx ||
          (t.legIdx == currentLegIdx &&
              currentPtIdx >= 0 &&
              t.ptIdx <= currentPtIdx);
      if (passed) {
        final id = turnMarkerId(t);
        _drawnModeATurnMarkerIds.remove(id);
        unawaited(
          ctrl
              .deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id))
              .catchError((_) {}),
        );
      } else {
        remaining.add(t);
      }
    }
    if (remaining.length != _allModeATurnMarkers.length) {
      _allModeATurnMarkers = remaining;
    }
  }

  Future<void> _drawModeATurnMarkers(List<TurnPoint> turns) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final ctx = context;

    for (final id in _drawnModeATurnMarkerIds) {
      await ctrl
          .deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id))
          .catchError((_) {});
    }
    _drawnModeATurnMarkerIds.clear();
    if (!mounted) return;

    for (final turn in turns) {
      if (turn.type == TurnType.straight || turn.type == TurnType.arrival)
        continue;

      final icon = await NOverlayImage.fromWidget(
        widget: _ModeATurnMarkerIcon(type: turn.type),
        size: const Size(28, 28),
        context: ctx,
      );
      if (!mounted) break;

      final id = turnMarkerId(turn);
      await ctrl.addOverlay(
        NMarker(
          id: id,
          position: NLatLng(turn.lat, turn.lng),
          icon: icon,
          anchor: const NPoint(0.5, 0.5),
          isHideCollidedMarkers: false,
        ),
      );
      _drawnModeATurnMarkerIds.add(id);
    }
    debugPrint(
      '[ModeA TurnDetect] drew ${_drawnModeATurnMarkerIds.length} map markers',
    );
  }

  Future<void> _clearModeAWalkTurnMarkers() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (final id in _drawnModeATurnMarkerIds) {
      ctrl
          .deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id))
          .catchError((_) {});
    }
    _drawnModeATurnMarkerIds.clear();
  }

  void _resetModeAWalkTurnState() {
    _modeATurnPoints = [];
    _allModeATurnMarkers = [];
    _modeARoadNearestPtIdx = 0;
    _lastModeARoadProgress = null;
    _modeAOffRouteStartTime = null;
    _modeARouteSource = null;
    _modeANavStepMode = false;
    _movedSinceModeANavStart = 0.0;
    _modeATransitNavStepMode = false;
  }

  // ── Transit step markers ───────────────────────────────────────

  int _transitStepMarkerCount = 0;

  /// 대중교통 → 도보/자전거 전환 시에도 호출되는 무조건 정리용 — 새 경로가
  /// transit이 아니면 _drawTransitStepMarkers 자체가 호출되지 않으므로, 그 안의
  /// 삭제 루프에만 의존하면 이전 대중교통 스텝 마커가 지도에 남는다.
  void _clearModeATransitStepMarkers() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    for (int i = 0; i < _transitStepMarkerCount; i++) {
      ctrl
          .deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: 'transit_step_$i'),
          )
          .catchError((_) {});
    }
    _transitStepMarkerCount = 0;
  }

  Future<void> _drawTransitStepMarkers(
    RouteResultEntity result,
    int activeIdx,
  ) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    _clearModeATransitStepMarkers();

    final steps = result.transitSteps;
    if (steps.isEmpty) {
      _transitStepMarkerCount = 0;
      return;
    }

    final ctx = context;

    for (int i = 0; i < steps.length; i++) {
      if (i == 0 && steps[i].isWalk) continue; // 출발지는 wp_origin A마커와 중복
      final step = steps[i];
      final lat = step.startLat;
      final lng = step.startLng;
      if (lat == null || lng == null) continue;

      final isActive = i == activeIdx;
      final isDone = i < activeIdx;

      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: step.trafficType,
          lineInfo: step.lineInfo,
          isActive: isActive,
          isDone: isDone,
        ),
        size: isActive ? const Size(52, 52) : const Size(36, 36),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;

      final captionText = step.isWalk
          ? (i == 0 ? '출발' : '${step.startName} 도보')
          : (step.lineInfo != null ? '${step.lineInfo} 승차' : step.startName);

      final captionColor = isActive
          ? (step.isBus ? kMapPrimary : context.colors.pinUser)
          : Colors.white54;

      final marker = NMarker(
        id: 'transit_step_$i',
        position: NLatLng(lat, lng),
        icon: icon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: isActive ? 12 : 10,
          color: captionColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: !isActive,
      )..setZIndex(isActive ? 10 : 0);
      await ctrl.addOverlay(marker);
    }

    final lastStep = steps.last;
    if (lastStep.endLat != null && lastStep.endLng != null) {
      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: 0,
          lineInfo: null,
          isActive: activeIdx >= steps.length - 1,
          isDone: false,
        ),
        size: const Size(40, 40),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;
      final marker = NMarker(
        id: 'transit_step_${steps.length}',
        position: NLatLng(lastStep.endLat!, lastStep.endLng!),
        icon: icon,
        caption: NOverlayCaption(
          text: '도착 · ${result.toName}',
          textSize: 11,
          color: context.colors.danger,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      )..setZIndex(5);
      await ctrl.addOverlay(marker);
    }
    _transitStepMarkerCount = steps.length + 1;
  }
}

/// Mode A 턴 마커 아이콘 — Mode B `_TurnDirectionMarker`와 동일한 모양/색상.
class _ModeATurnMarkerIcon extends StatelessWidget {
  const _ModeATurnMarkerIcon({required this.type});
  final TurnType type;

  IconData get _icon => switch (type) {
    TurnType.right => Icons.turn_right_rounded,
    TurnType.left => Icons.turn_left_rounded,
    TurnType.uTurn => Icons.u_turn_right_rounded,
    TurnType.arrival => Icons.flag_rounded,
    TurnType.straight => Icons.straight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: context.colors.accent,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(child: Icon(_icon, size: 16, color: Colors.white)),
    );
  }
}
