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

  NaverMapController? get _ctrl;
  Position? get _position;

  /// 기기 나침반 방위각 (map_overlay.dart의 _compassHeading 필드로 구현)
  double get _compassHeading;

  // mode_b_mixin에서 구현
  DraggableScrollableController get _sheetBCtrl;
  Future<List<NLatLng>> _fetchGpxPoints(String gpxUrl);
  List<NLatLng> get _lastGeneratedRoutePoints;
  Future<void> _rerouteGeneratedCourse(
      Position p, TouristRouteEntity route, int wpIdx);

  void _disposeModeBNav() {
    // nothing to dispose currently
  }

  // ── Navigation 시작 ───────────────────────────────────────────

  Future<void> _startModeBNavigation(
    TouristRouteEntity route,
    List<NLatLng> gpxPoints,
  ) async {
    final food = ref.read(selectedFoodProvider);
    final gpxPts = gpxPoints
        .map((p) => (lat: p.latitude, lng: p.longitude))
        .toList();

    await ref.read(modeBNavProvider.notifier).start(
          route: route,
          gpxPoints: gpxPts,
          foodKcal: food?.kcal ?? 0,
          foodName: food?.name ?? '',
        );

    if (mounted) {
      setState(() {
        _modeBNavCameraFollow = true;
        _modeBNavCameraUpdating = false;
        _modeBNavLastBearing = 0.0;
        _modeBNavPrevPosition = null;
      });
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
    });

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

    ref.read(modeBNavProvider.notifier).onPositionUpdate(
          p.latitude, p.longitude, weightKg, transport);

    // 이동 방향 계산 (GPS 기반)
    final prev = _modeBNavPrevPosition;
    if (prev != null) {
      final bearing = _calcModeBBearing(
          prev.latitude, prev.longitude, p.latitude, p.longitude);
      final moved = Geolocator.distanceBetween(
          prev.latitude, prev.longitude, p.latitude, p.longitude);
      if (moved >= 2.0) _modeBNavLastBearing = bearing;
    }
    _modeBNavPrevPosition = p;

    if (_modeBNavCameraFollow) {
      // north-up 모드: bearing=0 고정, heading-up 모드: 나침반 방위각 사용
      final cameraBearing = _modeBNorthUpMode ? 0.0 : _compassHeading;
      _followModeBCamera(p.latitude, p.longitude, cameraBearing);
    }

    // 생성 코스 이탈 감지 → 30초 유지 시 자동 재경로
    final route = navState.route;
    if (route != null && route.isGenerated) {
      final pts = _lastGeneratedRoutePoints;
      if (pts.isNotEmpty) {
        double minDist = double.infinity;
        for (var i = 0; i < pts.length; i += 5) {
          final d = Geolocator.distanceBetween(
              p.latitude, p.longitude, pts[i].latitude, pts[i].longitude);
          if (d < minDist) minDist = d;
        }
        if (minDist > 100) {
          _offRouteStartTime ??= DateTime.now();
          if (DateTime.now().difference(_offRouteStartTime!).inSeconds >= 30) {
            _offRouteStartTime = null;
            _showModeBOffRouteSnackBar();
            unawaited(
                _rerouteGeneratedCourse(p, route, navState.currentWaypointIdx));
          }
        } else {
          _offRouteStartTime = null;
        }
      }
    }
  }

  void _toggleNorthUpMode() {
    if (!mounted) return;
    setState(() => _modeBNorthUpMode = !_modeBNorthUpMode);
    // 즉시 카메라 bearing 반영
    final pos = _position;
    if (pos != null && _modeBNavCameraFollow) {
      final bearing = _modeBNorthUpMode ? 0.0 : _modeBNavLastBearing;
      _followModeBCamera(pos.latitude, pos.longitude, bearing);
    }
  }

  // ── 카메라 팔로우 ──────────────────────────────────────────────

  double _calcModeBBearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng = (lng2 - lng1) * toRad;
    final y = sin(dLng) * cos(lat2 * toRad);
    final x = cos(lat1 * toRad) * sin(lat2 * toRad) -
        sin(lat1 * toRad) * cos(lat2 * toRad) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

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
    if (!navState.isNavigating) return;
    final route = navState.route;
    if (route == null) return;

    final isArrived = route.isGenerated
        ? navState.currentWaypointIdx >= route.waypoints.length
        : navState.remainingDistanceM < 50;

    if (isArrived) {
      await _saveModeBRecord(navState);
      ref.read(modeBNavProvider.notifier).stop();
      _resetModeBNavCamera();
      _showModeBNavArrivalMessage(route.name);
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

  void _showModeBNavArrivalMessage(String routeName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4A90E2),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$routeName 완료!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const Text('목표 칼로리 소모 완료 🎉',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
    );
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
        backgroundColor: const Color(0xFFE67E22),
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

    return [
      // 상단 카드 / 스팟 캐러셀
      Positioned(
        top: MediaQuery.paddingOf(context).top + 8,
        left: 12,
        right: 12,
        child: route.isGenerated && route.waypoints.isNotEmpty
            ? _ModeBNavSpotCarousel(
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
                onStop: _stopModeBNavigation,
              )
            : _ModeBNavTopCard(navState: navState),
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

      // 나침반 버튼 (항상 표시 — 탭하면 north-up / heading-up 전환)
      Positioned(
        right: 12,
        bottom: 96 + bottomPad + 16 + 56,
        child: GestureDetector(
          onTap: _toggleNorthUpMode,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _modeBNorthUpMode
                  ? const Color(0xFF4A90E2)
                  : kMapPanel,
              shape: BoxShape.circle,
              border: Border.all(
                color: _modeBNorthUpMode
                    ? const Color(0xFF4A90E2)
                    : Colors.white24,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                // north-up 모드에서는 북쪽(0°), heading-up에서는 현재 bearing만큼 회전
                angle: _modeBNorthUpMode
                    ? 0
                    : -_modeBNavLastBearing * (3.14159 / 180),
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
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
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
