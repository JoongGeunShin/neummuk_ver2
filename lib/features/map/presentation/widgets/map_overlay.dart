import 'dart:async';
import 'dart:convert';
import 'dart:math' show pi;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/turn_point_utils.dart';
import '../../../../core/widgets/calorie_compare_donut.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../../core/widgets/tiny_ring.dart';
import '../../data/datasources/road_route_datasource.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../../mode_a/domain/entities/route_result_entity.dart';
import '../../../mode_a/domain/entities/waypoint_candidate_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_nav_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../mode_b/domain/entities/food_entity.dart';
import '../../../mode_b/domain/entities/spot_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../mode_b/presentation/providers/cart_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_nav_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../../../record/presentation/providers/record_provider.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../../walk/presentation/providers/walk_provider.dart';
import '../../domain/entities/place_entity.dart';
import '../common/camera_utils.dart';
import '../common/map_ui_atoms.dart';
import '../providers/map_mode_provider.dart';
import '../providers/map_provider.dart';

part 'map_overlay/shared_widgets.dart';
part 'map_overlay/explore_widgets.dart';
part 'map_overlay/explore_sheets.dart';
part 'map_overlay/mode_a_route_panel.dart';
part 'map_overlay/mode_a_result_sheet.dart';
part 'map_overlay/mode_a_calorie_widgets.dart';
part 'map_overlay/nav_transit_widgets.dart';
part 'map_overlay/mode_b_panels.dart';
part 'map_overlay/mode_b_cards.dart';
part 'map_overlay/explore_mixin.dart';
part 'map_overlay/nav_mixin.dart';
part 'map_overlay/mode_a_mixin.dart';
part 'map_overlay/mode_b_mixin.dart';
part 'map_overlay/mode_b_nav_mixin.dart';
part 'map_overlay/mode_b_nav_panels.dart';
part 'map_overlay/mode_a_walk_nav_panels.dart';

const _kPanel    = kMapPanel;
const _kPanelAlt = kMapPanelAlt;
const _kHandle   = kMapHandle;
const _kWhite87  = kMapWhite87;
const _kWhite45  = kMapWhite45;
const _kGreen    = kMapPrimary;
const _kTransit  = kMapTransit;

class MapOverlay extends ConsumerStatefulWidget {
  const MapOverlay({
    super.key,
    required this.controller,
    required this.events,
  });

  final NaverMapController? controller;
  final MapEventSink events;

  @override
  ConsumerState<MapOverlay> createState() => _MapOverlayState();
}

class _MapOverlayState extends ConsumerState<MapOverlay>
    with _ExploreOverlayMixin, _NavOverlayMixin, _ModeAOverlayMixin, _ModeBOverlayMixin, _ModeBNavOverlayMixin {

  @override Position? get _position => __position;
  Position? __position;

  @override bool get _locating => __locating;
  @override set _locating(bool value) => __locating = value;
  bool __locating = false;

  NLocationOverlay? _locationOverlay;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;

  // 기기 나침반 방위각 — _ModeBNavOverlayMixin abstract getter 충족
  double _compassHeading = 0.0;
  DateTime _lastCameraCompassUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  NaverMapController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.events.onMapTapped = _onMapTapped;
    widget.events.onLongTapped = _onLongTapped;
    widget.events.onCameraIdle = _onCameraIdle;
    widget.events.onCameraChange = _onCameraChange;
  }

  @override
  void didUpdateWidget(covariant MapOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller == null && widget.controller != null) {
      _onMapReady(widget.controller!);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _disposeExplore();
    _disposeModeA();
    _disposeModeB();
    _disposeModeBNav();
    super.dispose();
  }

  // ── Map ready ─────────────────────────────────────────────────

  Future<void> _onMapReady(NaverMapController ctrl) async {
    _locationOverlay = ctrl.getLocationOverlay();
    if (!mounted) return;

    // 방향 콘이 포함된 커스텀 위치 아이콘
    final locationBearingIcon = await NOverlayImage.fromWidget(
      widget: const _LocationBearingIcon(),
      size: const Size(80, 80),
      context: context,
    );
    if (mounted) {
      _locationOverlay?.setIcon(locationBearingIcon);
      _locationOverlay?.setAnchor(const NPoint(0.5, 0.5));
    }

    // 나침반 구독 — setBearing으로 콘 아이콘 회전, Mode A/B nav 카메라 bearing 갱신
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      setState(() => _compassHeading = heading);
      _locationOverlay?.setBearing(heading);

      final now = DateTime.now();
      if (now.difference(_lastCameraCompassUpdate).inMilliseconds < 800) return;

      final modeBNav = ref.read(modeBNavProvider);
      if (modeBNav.isNavigating && !_modeBNorthUpMode && _modeBNavCameraFollow) {
        _lastCameraCompassUpdate = now;
        final pos = __position;
        if (pos != null) {
          _followModeBCamera(pos.latitude, pos.longitude, heading);
        }
        return;
      }

      final modeANav = ref.read(modeANavProvider);
      if (modeANav.isNavigating && !_modeANorthUpMode && _navCameraFollow) {
        _lastCameraCompassUpdate = now;
        final pos = __position;
        if (pos != null) {
          _followNavCamera(pos.latitude, pos.longitude, heading);
        }
      }
    });

    final pos = await fetchMapPosition(
      accuracy: LocationAccuracy.high,
      timeout: const Duration(seconds: 10),
    );
    if (!mounted) return;

    if (pos != null) {
      setState(() => __position = pos);
      _locationOverlay!.setIsVisible(true);
      _locationOverlay!.setPosition(NLatLng(pos.latitude, pos.longitude));
      await ctrl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
        ),
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((p) {
      if (!mounted) return;
      setState(() => __position = p);
      _locationOverlay?.setPosition(NLatLng(p.latitude, p.longitude));

      // Mode A 네비게이션
      final navState = ref.read(modeANavProvider);
      if (navState.isNavigating) {
        final route = ref.read(modeAProvider).routeResult;
        if (route != null) {
          if (route.transport == 'transit') {
            _onModeATransitPositionUpdate(p, route);
          } else {
            _onModeAWalkBikePositionUpdate(p, route);
          }
        }
        final prev = _prevNavPosition;
        if (prev != null) {
          final bearing = bearingDeg(
              prev.latitude, prev.longitude, p.latitude, p.longitude);
          final moved = Geolocator.distanceBetween(
              prev.latitude, prev.longitude, p.latitude, p.longitude);
          if (moved >= 2.0) {
            _lastNavBearing = bearing;
            // 8m 이상 이동 시 자동으로 단계별 안내로 전환
            if (route != null && route.transport != 'transit' && !_modeANavStepMode) {
              _movedSinceModeANavStart += moved;
              if (_movedSinceModeANavStart > 8.0) {
                setState(() => _modeANavStepMode = true);
              }
            }
          }
        }
        _prevNavPosition = p;
        // Mode B와 동일: 카메라 베어링에 기기 나침반 사용 (north-up 아닐 때)
        _followNavCamera(
          p.latitude, p.longitude,
          _modeANorthUpMode ? 0.0 : _compassHeading,
        );
        // 잔여 폴리라인 실시간 트리밍 (스로틀 없이 완전 실시간)
        final currentNavState = ref.read(modeANavProvider);
        if (route?.transport == 'transit') {
          unawaited(_trimModeATransitPolylines(p, currentNavState));
        } else {
          unawaited(_trimModeAPolylineToRemaining(p, currentNavState));
        }
      }

      // Mode B 네비게이션
      final modeBNavState = ref.read(modeBNavProvider);
      if (modeBNavState.isNavigating) {
        _onModeBNavPositionUpdate(p, modeBNavState);
        unawaited(_trimNavPolylineToRemaining(p, ref.read(modeBNavProvider)));
      }
    });

    final lat = pos?.latitude ?? 37.5665;
    final lng = pos?.longitude ?? 126.9780;
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    final radius = await _getVisibleRadiusMeters();
    if (!mounted) return;
    ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);

    // 홈에서 진입 시 이미 모드 A 상태라면 마커·폴리라인 동기화 (안내 중 복원이면 순수 드로잉만)
    if (ref.read(mapModeProvider) == MapMode.modeA) {
      final modeAState = ref.read(modeAProvider);
      final modeANavState = ref.read(modeANavProvider);
      unawaited(_syncModeAMarkers(modeAState));
      if (modeANavState.isNavigating && modeAState.routeResult != null) {
        unawaited(_restoreModeANavOnMap(modeAState.routeResult!, modeANavState));
      } else {
        unawaited(_drawModeAPolyline(modeAState.routeResult));
      }
    }

    // 앱 재시작 복원: Mode B nav 상태 복원
    if (ref.read(mapModeProvider) == MapMode.modeB) {
      final navState = ref.read(modeBNavProvider);
      if (navState.isNavigating && navState.route != null) {
        if (navState.needsGpxReload) {
          // GPX 코스: GPX 파일 재로드
          unawaited(_reloadGpxForNavigation(navState.route!.gpxpath!));
        } else if (navState.route!.isGenerated) {
          // 생성 코스: 도로경로 재그리기 + 스팟 마커 복원
          unawaited(_restoreGeneratedCourseNav(navState));
        }
      }
    }
  }

  Future<void> _restoreGeneratedCourseNav(ModeBNavState navState) async {
    final route = navState.route!;
    if (route.waypoints.isEmpty) return;
    // 세그먼트 폴리라인 페치 (generated_course preview는 지우고 seg_* 로 교체)
    await _drawGeneratedCourseOnMap(route);
    if (!mounted) return;

    // 복원 후 seg_* 구간 형식으로 재그리기 (전체 경로 표시)
    if (_segmentPolylines.length == route.waypoints.length) {
      setState(() => _modeBShowAllSegments = true);
      await _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
      await _drawSegmentsOnMap(
        navState.currentWaypointIdx.clamp(0, route.waypoints.length - 1),
        showAll: true,
      );
      final dists = _segmentPolylines.map(_totalPolylineLength).toList();
      ref.read(modeBNavProvider.notifier).updateSegmentDistances(dists);

      // 턴 마커 복원 — 정상 시작 흐름(_startModeBNavigation)과 동일하게
      // 코스 전체 구간의 턴을 계산해 그린다. 이게 없으면 앱을 강제종료 후
      // 재실행했을 때 다음 웨이포인트 도착까지 턴 마커가 아예 안 보인다.
      final currentIdx =
          navState.currentWaypointIdx.clamp(0, _segmentPolylines.length - 1);
      final curSeg = _segmentPolylines[currentIdx];
      _modeBTurnPoints = curSeg.isNotEmpty
          ? computeTurnPoints(
              curSeg.map((p) => (lat: p.latitude, lng: p.longitude)).toList(),
              legIdx: currentIdx,
            )
          : [];
      _modeBRoadNearestPtIdx = 0;
      _allRouteTurnMarkers = _computeAllGeneratedRouteTurnPoints();
      if (mounted) unawaited(_drawTurnMarkersOnMap(_allRouteTurnMarkers));
    }

    if (!mounted) return;
    await _drawNavSpotMarkers(
      route.waypoints,
      currentIdx: navState.currentWaypointIdx,
    );
  }

  // ── Map events ────────────────────────────────────────────────

  void _onMapTapped(NPoint point, NLatLng latLng) {
    final mode = ref.read(mapModeProvider);
    if (mode == MapMode.explore) {
      _onExploreMapTap();
    } else if (mode == MapMode.modeA) {
      // 안내 중에는 UI 숨김 비활성
      if (!ref.read(modeANavProvider).isNavigating) _onModeAMapTap();
    }
  }

  void _onLongTapped(NPoint point, NLatLng latLng) {
    final mode = ref.read(mapModeProvider);
    if (mode == MapMode.explore || mode == MapMode.modeA) {
      _showLongPressSheet(latLng);
    }
  }

  Future<void> _onCameraIdle() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    if (mounted) setState(() {
      _currentZoom = cam.zoom;
    });
    final mode = ref.read(mapModeProvider);
    if (mode != MapMode.explore) return;
    final lat = cam.target.latitude;
    final lng = cam.target.longitude;
    ref.read(mapSearchNotifierProvider.notifier).updateCenter(lat, lng);
    if (_lastSearchLat != null) {
      final d = MapCameraUtils.distanceM(lat, lng, _lastSearchLat!, _lastSearchLng!);
      if (mounted) setState(() => _showReSearchButton = d > 300);
    }
  }

  void _onCameraChange(NCameraUpdateReason reason, bool animated) {
    if (!mounted) return;
    if (_navCameraUpdating) return;
    if (reason == NCameraUpdateReason.gesture) {
      if (ref.read(modeANavProvider).isNavigating && _navCameraFollow) {
        setState(() => _navCameraFollow = false);
      }
      _onModeBNavCameraGesture();
    }
  }

  void _onModeChanged(MapMode? prev, MapMode next) {
    if (prev == null) return;
    switch (next) {
      case MapMode.explore:
        _ctrl?.clearOverlays(type: NOverlayType.marker);
        _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
        _invalidateExploreMarkerCache();
        final lat = __position?.latitude ?? _lastSearchLat ?? 37.5665;
        final lng = __position?.longitude ?? _lastSearchLng ?? 126.9780;
        _lastSearchLat = lat;
        _lastSearchLng = lng;
        _getVisibleRadiusMeters().then((radius) {
          if (!mounted) return;
          ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
        });
      case MapMode.modeA:
        if (mounted) {
          setState(() {
            _showExploreList = false;
            _clusterPanelPlaces = null;
            _exploreMapFocus = false;
            _modeAMapFocus = false;    // 모드 진입 시 포커스 초기화
            _routePanelEditing = false; // 수정 패널 초기화
          });
        }
        if (__position != null) _locationOverlay?.setIsVisible(true);
        _clusterIconCache.clear();
        _ctrl?.clearOverlays(type: NOverlayType.marker);
        final modeAState = ref.read(modeAProvider);
        if (modeAState.originLat == null) _fetchGpsOriginForModeA();
        _syncModeAMarkers(modeAState);
        _drawModeAPolyline(modeAState.routeResult);
      case MapMode.modeB:
        _resetModeAFocusState();
        final modeBState = ref.read(routeSearchProvider);
        if (_currentSearchedSpots.isNotEmpty) {
          unawaited(_drawSearchedSpotMarkers(_currentSearchedSpots));
        } else if (modeBState.searchedSpots.isNotEmpty) {
          unawaited(_drawSearchedSpotMarkers(modeBState.searchedSpots));
        } else if (modeBState.routes.isNotEmpty) {
          unawaited(_updateModeBMarkers(modeBState.routes, selectedIdx: modeBState.selectedRouteIdx));
        } else {
          // 기성 코스·검색 결과 없는 초기 상태 → 카트 스팟만 표시
          final cartItems = ref.read(cartProvider);
          if (cartItems.isNotEmpty) unawaited(_addCartMarkersToMap(cartItems));
        }
    }
  }

  // ── Location helpers ──────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    if (_ctrl == null) return;
    setState(() => __locating = true);
    try {
      Position? pos = __position;
      pos ??= await fetchMapPosition(
        accuracy: LocationAccuracy.high,
        timeout: const Duration(seconds: 10),
      );
      if (!mounted || pos == null) return;
      await _ctrl!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
        ),
      );
    } finally {
      if (mounted) setState(() => __locating = false);
    }
  }

  Future<void> _zoomIn() async {
    if (_ctrl != null) await MapCameraUtils.zoomIn(_ctrl!);
  }

  Future<void> _zoomOut() async {
    if (_ctrl != null) await MapCameraUtils.zoomOut(_ctrl!);
  }

  // ── Zoom controls ─────────────────────────────────────────────

  Widget _buildZoomControls(
    BuildContext context,
    MapMode mode,
    double bottomPad,
    ModeAState modeAState,
    ModeANavState navState,
  ) {
    final zoomWidget = MapZoomControls(
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onLocation: _goToCurrentLocation,
      isLocating: __locating,
    );

    if (mode == MapMode.modeA && navState.isNavigating) {
      return Positioned(right: 12, bottom: 96 + bottomPad + 16, child: zoomWidget);
    }
    if (mode == MapMode.modeB && ref.read(modeBNavProvider).isNavigating) {
      return Positioned(right: 12, bottom: 96 + bottomPad + 16, child: zoomWidget);
    }
    if (mode == MapMode.modeB) {
      return AnimatedBuilder(
        animation: _sheetBCtrl,
        builder: (context, child) {
          final screenH = MediaQuery.sizeOf(context).height;
          final sheetH = _sheetBCtrl.isAttached
              ? _sheetBCtrl.size * screenH
              : screenH * 0.46;
          return Positioned(right: 12, bottom: sheetH + 16, child: child!);
        },
        child: zoomWidget,
      );
    }
    if (mode == MapMode.explore && _showExploreList) {
      return AnimatedBuilder(
        animation: _sheetExploreCtrl,
        builder: (context, child) {
          final screenH = MediaQuery.sizeOf(context).height;
          final sheetH = _sheetExploreCtrl.isAttached
              ? _sheetExploreCtrl.size * screenH
              : screenH * 0.42;
          return Positioned(right: 12, bottom: sheetH + 16, child: child!);
        },
        child: zoomWidget,
      );
    }
    if (mode == MapMode.modeA && modeAState.routeResult != null) {
      return AnimatedBuilder(
        animation: _sheetACtrl,
        builder: (context, child) {
          final screenH = MediaQuery.sizeOf(context).height;
          final sheetH = _sheetACtrl.isAttached
              ? _sheetACtrl.size * screenH
              : screenH * 0.52;
          return Positioned(right: 12, bottom: sheetH + bottomPad + 16, child: child!);
        },
        child: zoomWidget,
      );
    }
    return Positioned(right: 12, bottom: bottomPad + 16, child: zoomWidget);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final mode         = ref.watch(mapModeProvider);
    final exploreState = ref.watch(mapSearchNotifierProvider);
    final modeAState   = ref.watch(modeAProvider);
    final navState     = ref.watch(modeANavProvider);
    final food         = ref.watch(selectedFoodProvider);
    final modeBState   = ref.watch(routeSearchProvider);
    final modeBNavState = ref.watch(modeBNavProvider);
    final profileAsync = ref.watch(userProfileProvider);

    ref.listen<MapMode>(mapModeProvider, _onModeChanged);

    ref.listen(
      mapSearchNotifierProvider.select((s) => s.places),
      (_, places) {
        if (mode == MapMode.explore) {
          _updateExploreMarkers(places);
          if (_fitCameraOnNextResult && places.isNotEmpty) {
            _fitCameraOnNextResult = false;
            _fitCameraToPlaces(places);
          }
        }
      },
    );

    ref.listen<ModeAState>(modeAProvider, (prev, next) {
      final coordsChanged = prev?.originLat != next.originLat ||
          prev?.originLng != next.originLng ||
          prev?.destLat != next.destLat ||
          prev?.destLng != next.destLng ||
          prev?.waypoints.length != next.waypoints.length;
      if (coordsChanged) {
        _syncModeAMarkers(next);
        if (next.destLat == null) _drawModeAPolyline(null);
      }
      if (prev?.routeResult != next.routeResult) {
        _drawModeAPolyline(next.routeResult);
        if (next.routeResult == null && mounted) {
          setState(() => _routePanelEditing = false);
          _clearNearbyMarkers();
        }
      }
      // 탭 전환 or 데이터 로딩 완료 → 마커 갱신
      final tabChanged = prev?.nearbyTab != next.nearbyTab;
      final loadFinished =
          (prev?.nearbyLoading ?? false) && !next.nearbyLoading;
      final restaurantsRefreshed = next.nearbyTab == ModeANearbyTab.restaurant &&
          !identical(prev?.restaurants, next.restaurants) &&
          next.routeResult != null;
      if ((tabChanged || loadFinished || restaurantsRefreshed) &&
          next.routeResult != null) {
        _updateNearbyMarkers(next);
      }
    });

    ref.listen<RouteSearchState>(routeSearchProvider, (prev, next) {
      // 스팟 검색 결과 변경 → 마커 갱신
      if (!identical(prev?.searchedSpots, next.searchedSpots) &&
          next.searchedSpots.isNotEmpty) {
        unawaited(_drawSearchedSpotMarkers(next.searchedSpots));
      }
      // 태그/주변코스 해제 시 마커 정리
      if ((prev?.activeSpotTag != null && next.activeSpotTag == null) ||
          ((prev?.nearbyCoursesActive ?? false) && !next.nearbyCoursesActive)) {
        if (!next.nearbyCoursesActive && next.activeSpotTag == null) {
          _ctrl?.clearOverlays(type: NOverlayType.marker);
          _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
        }
      }
      // 기성 코스 목록 변경 시 마커 갱신 (생성 코스 선택 중에는 기성 마커 갱신 생략)
      if (!next.isLoading && next.routes != prev?.routes && !next.generatedCourseSelected) {
        _updateModeBMarkers(next.routes, selectedIdx: next.selectedRouteIdx);
      }
      // 기성 코스 선택 변경 시 GPX/마커 갱신
      if (next.selectedRouteIdx != prev?.selectedRouteIdx &&
          next.selectedRouteIdx >= 0 &&
          next.routes.isNotEmpty) {
        _loadModeBRouteGpx(next.selectedRouteIdx);
      }
      // 생성 코스 완성 → 지도에 표시 + 자동 선택 (안내 시작 버튼 즉시 노출)
      if (prev?.generatedCourse?.id != next.generatedCourse?.id &&
          next.generatedCourse != null) {
        _segmentPolylines = []; // 이전 코스 구간 캐시 초기화
        _generatedCourseRouteSource = null;
        unawaited(_drawGeneratedCourseOnMap(next.generatedCourse!));
        ref.read(routeSearchProvider.notifier).selectGeneratedCourse();
        // sheet를 기본 높이로 올려 카드가 보이도록
        if (_sheetBCtrl.isAttached) {
          _sheetBCtrl.animateTo(
            0.46,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      }
      // place_detail_screen에서 "안내 시작" 탭 → navPending 감지
      if (!(prev?.navPending ?? false) && next.navPending) {
        ref.read(routeSearchProvider.notifier).clearNavPending();
        final route = next.selectedRoute;
        if (route != null) _onStartModeBCourse(route);
      }
      // 스팟 검색 완료 후 코스 생성 실패 피드백
      final fetchDone = (prev?.isFetchingSpots ?? false) && !next.isFetchingSpots;
      if (fetchDone && next.generatedCourse == null && next.searchedSpots.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('주변에 코스를 만들 스팟이 부족해요. 태그를 바꾸거나 지도를 이동 후 다시 시도해보세요.'),
            backgroundColor: kMapPanel,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // 장바구니 변경 → Mode B 탐색 중 카트 마커 즉시 갱신
    ref.listen<List<SpotEntity>>(cartProvider, (prev, next) {
      final currentMode = ref.read(mapModeProvider);
      if (currentMode != MapMode.modeB) return;
      if (ref.read(modeBNavProvider).isNavigating) return;
      if (ref.read(routeSearchProvider).generatedCourseSelected) return;
      unawaited(_refreshCartMarkersOnMap(next));
    });

    ref.listen<ModeANavState>(modeANavProvider, (prev, next) {
      if ((prev?.isNavigating ?? false) &&
          next.isNavigating &&
          next.remainingDistanceM < 50) {
        ref.read(modeANavProvider.notifier).stop();
        _resetNavCamera();
        _showArrivalMessage();
      }
      // 네비게이션 시작 → overview 초기화 + 방향 전환 포인트 계산 + 구간 폴리라인 표시
      if (!(prev?.isNavigating ?? false) && next.isNavigating) {
        // 주의: 여기서 _clearTransitNavPolylines()를 호출하면 안 된다 — "코스생성" 때
        // 그려둔 _transitNavPolylines 핸들 캐시를 지워버려서, 안내 중 실시간 트리밍
        // (_trimModeATransitPolylines)이 대상 오버레이를 못 찾아 색이 고정돼버린다.
        // 다음 세션을 위한 정리는 네비 종료 분기(아래)에서 이미 담당한다.
        final route = ref.read(modeAProvider).routeResult;
        if (route != null && route.transport == 'transit') {
          if (mounted) setState(() => _modeATransitNavStepMode = false);
          _initModeATurnPoints(route);
          if (_allModeATurnMarkers.any((t) => t.type != TurnType.arrival)) {
            unawaited(_drawModeATurnMarkers(_allModeATurnMarkers));
          }
        } else if (route != null) {
          if (mounted) setState(() {
            _modeANavStepMode = false;
            _movedSinceModeANavStart = 0.0;
          });
          _initModeATurnPoints(route);
          unawaited(_drawModeASegmentsOnMap(route, 0));
          if (_allModeATurnMarkers.any((t) => t.type != TurnType.arrival)) {
            unawaited(_drawModeATurnMarkers(_allModeATurnMarkers));
          }
        }
      }
      // 네비게이션 종료
      if ((prev?.isNavigating ?? false) && !next.isNavigating) {
        unawaited(_clearModeAWalkTurnMarkers());
        _clearTransitNavPolylines();
        if (mounted) setState(_resetModeAWalkTurnState);
        ref.read(modeAProvider.notifier).clearRouteResult();
      }
      // 대중교통 도보 구간 이탈 — 도보/자전거는 다이얼로그+자동 재경로(nav_mixin.dart에서
      // 직접 트리거)로 처리하므로, 여기서는 대중교통일 때만 스낵바로 안내한다
      // (Mode B GPX 코스의 이탈 처리와 동일한 수준).
      if (!(prev?.isOffRoute ?? false) && next.isOffRoute) {
        final route = ref.read(modeAProvider).routeResult;
        if (route?.transport == 'transit') {
          _showModeAOffRouteSnackBar();
        }
      }
      if ((prev?.currentTransitStepIdx ?? 0) != next.currentTransitStepIdx) {
        final route = ref.read(modeAProvider).routeResult;
        if (route != null && route.transport == 'transit') {
          _drawTransitStepMarkers(route, next.currentTransitStepIdx);
        }
      }
    });

    // Mode B 네비게이션 이벤트
    ref.listen<ModeBNavState>(modeBNavProvider, (prev, next) {
      if (!next.isNavigating) return;

      // 도착 감지
      if (prev?.isNavigating ?? false) unawaited(_checkModeBNavArrival(next));

      // 경로 이탈 감지 (GPX 코스)
      if (!(prev?.isOffRoute ?? false) && next.isOffRoute) {
        _showModeBOffRouteSnackBar();
      }

      // 앱 재시작 후 GPX 포인트 재로드
      if (next.needsGpxReload && !(prev?.needsGpxReload ?? false)) {
        unawaited(_reloadGpxForNavigation(next.route!.gpxpath!));
      }

      // 생성 코스: 경유지 도달 시 마커 + 캐러셀 동기화
      if ((next.route?.isGenerated ?? false) &&
          next.currentWaypointIdx != (prev?.currentWaypointIdx ?? 0) &&
          (next.route?.waypoints.isNotEmpty ?? false)) {
        _drawNavSpotMarkers(
          next.route!.waypoints,
          currentIdx: next.currentWaypointIdx,
        );
        if (mounted) {
          final wps = next.route!.waypoints;
          final clampedIdx = next.currentWaypointIdx.clamp(0, wps.length - 1);
          setState(() => _modeBNavWaypointPageIdx = clampedIdx);
        }
      }
    });

    final categories = ['전체', ...?profileAsync.valueOrNull?.preferredCategories];

    return PopScope(
      canPop: !modeBNavState.isNavigating && !navState.isNavigating,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (navState.isNavigating) {
          final confirmed = await _showModeAExitNavConfirmDialog();
          if (!confirmed || !mounted) return;
          ref.read(modeANavProvider.notifier).stop();
          await _resetNavCamera();
          if (mounted) _modeASafeBack();
          return;
        }
        final confirmed = await _showModeBExitNavConfirmDialog();
        if (!confirmed || !mounted) return;
        await _stopModeBNavigation();
        if (mounted) _modeBSafeBack();
      },
      child: Stack(
      fit: StackFit.expand,
      children: [
        // ── Explore overlays ───────────────────────────────────
        ..._buildExploreOverlays(context, mode, exploreState, categories, bottomPad),

        // ── Mode A overlays ────────────────────────────────────
        ..._buildModeAOverlays(context, mode, modeAState, navState, bottomPad),

        // ── Mode B overlays (코스 탐색) ────────────────────────
        if (!modeBNavState.isNavigating)
          ..._buildModeBOverlays(context, mode, food, modeBState, bottomPad, __locating),

        // ── Mode B nav overlays (네비게이션 중) ────────────────
        if (mode == MapMode.modeB)
          ..._buildModeBNavOverlays(context, modeBNavState, bottomPad),

        // ── Zoom controls ──────────────────────────────────────
        _buildZoomControls(context, mode, bottomPad, modeAState, navState),

        // ── Mode B nav 플로팅 버튼 (줌 위에 렌더링) ────────────
        if (mode == MapMode.modeB && modeBNavState.isNavigating)
          ..._buildModeBNavFloatingButtons(bottomPad),

        // ── Mode A nav 플로팅 버튼 (Mode B와 동일: 나침반 토글 + 재센터) ──
        if (mode == MapMode.modeA && navState.isNavigating)
          ..._buildModeANavFloatingButtons(bottomPad),

        // ── Mode toggle (탐색 중 또는 경로 결과 시트·안내 중이면 숨김) ──
        if (mode != MapMode.modeB &&
            !navState.isNavigating &&
            !modeBNavState.isNavigating &&
            !(mode == MapMode.explore && _showExploreList) &&
            !(mode == MapMode.modeA &&
                modeAState.routeResult != null &&
                !_routePanelEditing))
          Positioned(
            left: 12, bottom: bottomPad + 16,
            child: _ModeToggle(
              mode: mode,
              onExplore: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.explore),
              onModeA: () {
                ref.read(mapModeProvider.notifier).set(MapMode.modeA);
                if (ref.read(modeAProvider).originLat == null) {
                  _fetchGpsOriginForModeA();
                }
              },
            ),
          ),

        // ── Explore: place sheet ───────────────────────────────
        if (mode == MapMode.explore && exploreState.selectedPlace != null)
          _ExplorePlaceSheet(
            place: exploreState.selectedPlace!,
            canAddWaypoint: ref.read(modeAProvider).waypoints.length < 3,
            onClose: () =>
                ref.read(mapSearchNotifierProvider.notifier).selectPlace(null),
            onSetOrigin: (place) {
              ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
              ref.read(modeAProvider.notifier).setOriginGps(
                    place.latitude, place.longitude, place.name);
              ref.read(mapModeProvider.notifier).set(MapMode.modeA);
            },
            onSetDest: (place) {
              ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
              ref.read(modeAProvider.notifier).setDestCoords(
                    place.latitude, place.longitude, place.name);
              ref.read(mapModeProvider.notifier).set(MapMode.modeA);
            },
            onAddWaypoint: (place) {
              ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
              ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                  ));
              ref.read(mapModeProvider.notifier).set(MapMode.modeA);
            },
            onViewDetail: (place) => context.push('/place-detail', extra: place),
          ),

        // ── Explore: cluster panel ─────────────────────────────
        if (mode == MapMode.explore &&
            _clusterPanelPlaces != null &&
            exploreState.selectedPlace == null)
          _ClusterPanel(
            places: _clusterPanelPlaces!,
            onClose: () => setState(() => _clusterPanelPlaces = null),
            onTapPlace: (place) {
              setState(() => _clusterPanelPlaces = null);
              ref.read(mapSearchNotifierProvider.notifier).selectPlace(place);
            },
          ),
      ],
      ),
    );
  }
}
