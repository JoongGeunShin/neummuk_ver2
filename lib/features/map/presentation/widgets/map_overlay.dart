import 'dart:async';
import 'dart:math' show pi, sin, cos, atan2;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../../core/widgets/tiny_ring.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../../mode_a/domain/entities/route_result_entity.dart';
import '../../../mode_a/domain/entities/waypoint_candidate_entity.dart';
import '../../../mode_a/presentation/providers/mode_a_nav_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../mode_b/domain/entities/food_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
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
part 'map_overlay/nav_cards.dart';
part 'map_overlay/nav_transit_widgets.dart';
part 'map_overlay/mode_b_panels.dart';
part 'map_overlay/mode_b_cards.dart';
part 'map_overlay/explore_mixin.dart';
part 'map_overlay/nav_mixin.dart';
part 'map_overlay/mode_a_mixin.dart';
part 'map_overlay/mode_b_mixin.dart';

const _kPanel    = kMapPanel;
const _kPanelAlt = kMapPanelAlt;
const _kHandle   = kMapHandle;
const _kWhite87  = kMapWhite87;
const _kWhite45  = kMapWhite45;
const _kGreen    = kMapGreen;

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
    with _ExploreOverlayMixin, _NavOverlayMixin, _ModeAOverlayMixin, _ModeBOverlayMixin {

  @override Position? get _position => __position;
  Position? __position;

  @override bool get _locating => __locating;
  @override set _locating(bool value) => __locating = value;
  bool __locating = false;

  NLocationOverlay? _locationOverlay;
  StreamSubscription<Position>? _positionSub;

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
    _disposeExplore();
    _disposeModeB();
    super.dispose();
  }

  // ── Map ready ─────────────────────────────────────────────────

  Future<void> _onMapReady(NaverMapController ctrl) async {
    _locationOverlay = ctrl.getLocationOverlay();
    if (!mounted) return;

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
        distanceFilter: 10,
      ),
    ).listen((p) {
      if (!mounted) return;
      setState(() => __position = p);
      _locationOverlay?.setPosition(NLatLng(p.latitude, p.longitude));

      final navState = ref.read(modeANavProvider);
      if (navState.isNavigating) {
        final route = ref.read(modeAProvider).routeResult;
        if (route != null) {
          ref.read(modeANavProvider.notifier).onPositionUpdate(
                p.latitude, p.longitude, route);
        }
        final prev = _prevNavPosition;
        if (prev != null) {
          final bearing = _calcBearing(
              prev.latitude, prev.longitude, p.latitude, p.longitude);
          final moved = Geolocator.distanceBetween(
              prev.latitude, prev.longitude, p.latitude, p.longitude);
          if (moved >= 2.0) _lastNavBearing = bearing;
        }
        _prevNavPosition = p;
        _followNavCamera(p.latitude, p.longitude, _lastNavBearing);
      }
    });

    final lat = pos?.latitude ?? 37.5665;
    final lng = pos?.longitude ?? 126.9780;
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    final radius = await _getVisibleRadiusMeters();
    if (!mounted) return;
    ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
  }

  // ── Map events ────────────────────────────────────────────────

  void _onMapTapped(NPoint point, NLatLng latLng) {
    if (ref.read(mapModeProvider) == MapMode.explore) {
      if (ref.read(mapSearchNotifierProvider).selectedPlace != null) {
        ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
      }
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
    if (mounted) setState(() => _currentZoom = cam.zoom);
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
    if (!mounted || _navCameraUpdating) return;
    if (reason == NCameraUpdateReason.gesture &&
        ref.read(modeANavProvider).isNavigating &&
        _navCameraFollow) {
      setState(() => _navCameraFollow = false);
    }
  }

  void _onModeChanged(MapMode? prev, MapMode next) {
    if (prev == null) return;
    switch (next) {
      case MapMode.explore:
        _ctrl?.clearOverlays(type: NOverlayType.marker);
        _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
        final lat = __position?.latitude ?? _lastSearchLat ?? 37.5665;
        final lng = __position?.longitude ?? _lastSearchLng ?? 126.9780;
        _lastSearchLat = lat;
        _lastSearchLng = lng;
        _getVisibleRadiusMeters().then((radius) {
          if (!mounted) return;
          ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
        });
      case MapMode.modeA:
        if ((_showExploreList || _clusterPanelPlaces != null) && mounted) {
          setState(() {
            _showExploreList = false;
            _clusterPanelPlaces = null;
          });
        }
        if (__position != null) _locationOverlay?.setIsVisible(true);
        _clusterIconCache.clear();
        final modeAState = ref.read(modeAProvider);
        if (modeAState.originLat == null) _fetchGpsOriginForModeA();
        _syncModeAMarkers(modeAState);
        _drawModeAPolyline(modeAState.routeResult);
      case MapMode.modeB:
        final routes = ref.read(routeSearchProvider).routes;
        if (routes.isNotEmpty) _updateModeBMarkers(routes);
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
      return Positioned(
        right: 12,
        bottom: context.screenHeight * (_sheetAExpanded ? 0.82 : 0.52) + bottomPad + 16,
        child: zoomWidget,
      );
    }
    return Positioned(right: 12, bottom: bottomPad + 16, child: zoomWidget);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final mode       = ref.watch(mapModeProvider);
    final exploreState = ref.watch(mapSearchNotifierProvider);
    final modeAState   = ref.watch(modeAProvider);
    final navState     = ref.watch(modeANavProvider);
    final food         = ref.watch(selectedFoodProvider);
    final modeBState   = ref.watch(routeSearchProvider);
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
      }
    });

    ref.listen<RouteSearchState>(routeSearchProvider, (prev, next) {
      if (!next.isLoading && next.routes != prev?.routes) {
        _updateModeBMarkers(next.routes);
      }
    });

    ref.listen<ModeANavState>(modeANavProvider, (prev, next) {
      if (next.showReroutePrompt && !(prev?.showReroutePrompt ?? false)) {
        _showRerouteDialog();
      }
      if ((prev?.isNavigating ?? false) &&
          next.isNavigating &&
          next.remainingDistanceM < 50) {
        ref.read(modeANavProvider.notifier).stop();
        _resetNavCamera();
        _showArrivalMessage();
      }
      if ((prev?.currentTransitStepIdx ?? 0) != next.currentTransitStepIdx) {
        final route = ref.read(modeAProvider).routeResult;
        if (route != null && route.transport == 'transit') {
          _drawTransitStepMarkers(route, next.currentTransitStepIdx);
        }
      }
    });

    final categories = ['전체', ...?profileAsync.valueOrNull?.preferredCategories];

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Explore overlays ───────────────────────────────────
        ..._buildExploreOverlays(context, mode, exploreState, categories, bottomPad),

        // ── Mode A overlays ────────────────────────────────────
        ..._buildModeAOverlays(context, mode, modeAState, navState, bottomPad),

        // ── Mode B overlays ────────────────────────────────────
        ..._buildModeBOverlays(context, mode, food, modeBState, bottomPad, __locating),

        // ── Nav re-center button ───────────────────────────────
        if (mode == MapMode.modeA && navState.isNavigating && !_navCameraFollow)
          Positioned(
            right: 12,
            bottom: 96 + bottomPad + 16 + 48 + 6 + 48 + 6 + 56,
            child: GestureDetector(
              onTap: _recenterNav,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: kMapGreen, shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.navigation_rounded, size: 24, color: Colors.white),
              ),
            ),
          ),

        // ── Zoom controls ──────────────────────────────────────
        _buildZoomControls(context, mode, bottomPad, modeAState, navState),

        // ── Mode toggle ────────────────────────────────────────
        if (mode != MapMode.modeB)
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
    );
  }
}
