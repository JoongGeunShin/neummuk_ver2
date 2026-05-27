import 'dart:async';

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

// ─── Constants ───────────────────────────────────────────────────────────────
const _kPanel    = kMapPanel;
const _kPanelAlt = kMapPanelAlt;
const _kHandle   = kMapHandle;
const _kWhite87  = kMapWhite87;
const _kWhite45  = kMapWhite45;

// ─── MapOverlay ───────────────────────────────────────────────────────────────

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

class _MapOverlayState extends ConsumerState<MapOverlay> {
  // ── Shared state ──────────────────────────────────────────────
  Position? _position;
  bool _locating = false;
  NLocationOverlay? _locationOverlay;
  StreamSubscription<Position>? _positionSub;

  // ── Explore state ─────────────────────────────────────────────
  Map<PlaceSource, NOverlayImage>? _markerIcons;
  double? _lastSearchLat;
  double? _lastSearchLng;
  bool _showReSearchButton = false;
  bool _fitCameraOnNextResult = false;
  final _searchCtrl = TextEditingController();

  // ── Mode A state ──────────────────────────────────────────────
  bool _sheetAExpanded = false;
  Map<String, NOverlayImage>? _routeMarkerIcons;

  // ── Phase 5: cluster state ─────────────────────────────────────
  double _currentZoom = 14.0;
  final Map<int, NOverlayImage> _clusterIconCache = {};

  // ── Mode B state ──────────────────────────────────────────────
  bool _gpxLoading = false;
  final _sheetBCtrl = DraggableScrollableController();

  NaverMapController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();

    // Register map events
    widget.events.onMapTapped = _onMapTapped;
    widget.events.onLongTapped = _onLongTapped;
    widget.events.onCameraIdle = _onCameraIdle;

    // Mode A: init GPS origin after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(modeAProvider).originLat == null) {
        // Will be triggered on map ready via _onModeChanged
      }
    });
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
    _searchCtrl.dispose();
    _sheetBCtrl.dispose();
    super.dispose();
  }

  // ── Map ready ─────────────────────────────────────────────────

  Future<void> _onMapReady(NaverMapController ctrl) async {
    // Set up location overlay
    _locationOverlay = ctrl.getLocationOverlay();
    if (!mounted) return;

    final pos = await fetchMapPosition(
      accuracy: LocationAccuracy.high,
      timeout: const Duration(seconds: 10),
    );
    if (!mounted) return;

    if (pos != null) {
      setState(() => _position = pos);
      _locationOverlay!.setIsVisible(true);
      _locationOverlay!.setPosition(NLatLng(pos.latitude, pos.longitude));
      await ctrl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
        ),
      );
    }

    // Start position stream
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      _locationOverlay?.setPosition(NLatLng(p.latitude, p.longitude));
      // Phase 6: update navigation state
      final navState = ref.read(modeANavProvider);
      if (navState.isNavigating) {
        final route = ref.read(modeAProvider).routeResult;
        if (route != null) {
          ref.read(modeANavProvider.notifier).onPositionUpdate(
                p.latitude, p.longitude, route);
        }
      }
    });

    // Initialize explore places
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
    final mode = ref.read(mapModeProvider);
    if (mode == MapMode.explore) {
      if (ref.read(mapSearchNotifierProvider).selectedPlace != null) {
        ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
      }
    }
    // modeA / modeB: do nothing
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
    // Update current zoom for clustering
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

  // ── Mode change ───────────────────────────────────────────────

  void _onModeChanged(MapMode? prev, MapMode next) {
    if (prev == null) return; // skip first build
    switch (next) {
      case MapMode.explore:
        _ctrl?.clearOverlays(type: NOverlayType.marker);
        _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
        // Reload places at current position
        final lat = _position?.latitude ?? _lastSearchLat ?? 37.5665;
        final lng = _position?.longitude ?? _lastSearchLng ?? 126.9780;
        _lastSearchLat = lat;
        _lastSearchLng = lng;
        _getVisibleRadiusMeters().then((radius) {
          if (!mounted) return;
          ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
        });
      case MapMode.modeA:
        if (_position != null) _locationOverlay?.setIsVisible(true);
        _clusterIconCache.clear();
        final modeAState = ref.read(modeAProvider);
        // Init GPS origin if not set
        if (modeAState.originLat == null) {
          _fetchGpsOriginForModeA();
        }
        _syncModeAMarkers(modeAState);
        // 기존 경로 결과가 있으면 폴리라인 재표시
        _drawModeAPolyline(modeAState.routeResult);
      case MapMode.modeB:
        final routes = ref.read(routeSearchProvider).routes;
        if (routes.isNotEmpty) {
          _updateModeBMarkers(routes);
        }
    }
  }

  // ── Location helpers ──────────────────────────────────────────

  Future<String?> _reverseGeocode(double lat, double lng) =>
      ref.read(placeRepositoryProvider).reverseGeocode(lat, lng);

  Future<Map<String, NOverlayImage>> _getRouteMarkerIcons() async {
    if (_routeMarkerIcons != null) return _routeMarkerIcons!;
    final originIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFF2ECC71), label: 'A'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final destIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFE74C3C), label: 'B'),
      size: const Size(30, 30),
      context: context,
    );
    if (!mounted) return {};
    final wpIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFF39C12), label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    _routeMarkerIcons = {'origin': originIcon, 'dest': destIcon, 'waypoint': wpIcon};
    return _routeMarkerIcons!;
  }

  Future<void> _syncModeAMarkers(ModeAState s) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    const ids = ['wp_origin', 'wp_dest', 'wp_0', 'wp_1', 'wp_2'];
    for (final id in ids) {
      try {
        await ctrl.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id));
      } catch (_) {}
    }
    final icons = await _getRouteMarkerIcons();
    if (!mounted) return;
    if (s.originLat != null && s.originLng != null) {
      final m = NMarker(
        id: 'wp_origin',
        position: NLatLng(s.originLat!, s.originLng!),
        icon: icons['origin'],
        caption: NOverlayCaption(
          text: s.from, textSize: 11,
          color: const Color(0xFF2ECC71), haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      );
      await ctrl.addOverlay(m);
    }
    if (s.destLat != null && s.destLng != null) {
      final m = NMarker(
        id: 'wp_dest',
        position: NLatLng(s.destLat!, s.destLng!),
        icon: icons['dest'],
        caption: NOverlayCaption(
          text: s.to, textSize: 11,
          color: const Color(0xFFE74C3C), haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      );
      await ctrl.addOverlay(m);
    }
    for (var i = 0; i < s.waypoints.length; i++) {
      final wp = s.waypoints[i];
      final m = NMarker(
        id: 'wp_$i',
        position: NLatLng(wp.latitude, wp.longitude),
        icon: icons['waypoint'],
        caption: NOverlayCaption(
          text: wp.name, textSize: 11,
          color: const Color(0xFFF39C12), haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      );
      await ctrl.addOverlay(m);
    }
  }

  // ── Mode A 경로 폴리라인 ──────────────────────────────────────────

  /// routeResult.routePoints 가 있으면 지도에 그린다.
  /// null 이거나 points 가 비어 있으면 기존 폴리라인만 지운다.
  Future<void> _drawModeAPolyline(RouteResultEntity? result) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.deleteOverlay(
      const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'mode_a_route'),
    ).catchError((_) {});
    if (result == null || result.routePoints.isEmpty) return;

    final coords = result.routePoints
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();

    final color = switch (result.transport) {
      'walk'    => const Color(0xFF03C75A),  // 초록
      'bike'    => const Color(0xFFFFB547),  // 주황
      'transit' => const Color(0xFF7C8AFF),  // 보라
      _         => const Color(0xFF03C75A),
    };

    await ctrl.addOverlay(NPolylineOverlay(
      id: 'mode_a_route',
      coords: coords,
      color: color,
      width: 5,
      lineCap: NLineCap.round,
      lineJoin: NLineJoin.round,
    ));

    // 전체 경로 + 마커가 보이도록 카메라 조정
    if (mounted) {
      await MapCameraUtils.fitPoints(
        ctrl,
        coords,
        padding: const EdgeInsets.fromLTRB(60, 180, 60, 320),
      );
    }
  }

  Future<void> _fitCameraToPlaces(List<PlaceEntity> places) async {
    if (_ctrl == null || places.isEmpty) return;
    await MapCameraUtils.fitPoints(
      _ctrl!,
      places.map((p) => NLatLng(p.latitude, p.longitude)).toList(),
      padding: const EdgeInsets.all(64),
    );
  }

  Future<void> _goToCurrentLocation() async {
    if (_ctrl == null) return;
    setState(() => _locating = true);
    try {
      Position? pos = _position;
      if (pos == null) {
        pos = await fetchMapPosition(
          accuracy: LocationAccuracy.high,
          timeout: const Duration(seconds: 10),
        );
      }
      if (!mounted || pos == null) return;
      await _ctrl!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _fetchGpsOriginForModeA() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      final pos = _position ?? await fetchMapPosition();
      if (!mounted || pos == null) return;
      ref.read(modeAProvider.notifier).setOriginGps(
            pos.latitude, pos.longitude, '현재 위치');
      await _ctrl?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 14,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _zoomIn() async {
    if (_ctrl == null) return;
    await MapCameraUtils.zoomIn(_ctrl!);
  }

  Future<void> _zoomOut() async {
    if (_ctrl == null) return;
    await MapCameraUtils.zoomOut(_ctrl!);
  }

  // ── Explore helpers ───────────────────────────────────────────

  Future<int> _getVisibleRadiusMeters() async {
    if (_ctrl == null) return 3000;
    return MapCameraUtils.visibleRadiusMeters(_ctrl!);
  }

  Future<void> _onSearchSubmit(String value) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final radius = await _getVisibleRadiusMeters();
    if (!mounted) return;
    _fitCameraOnNextResult = value.isNotEmpty;
    ref.read(mapSearchNotifierProvider.notifier).search(value, radiusMeters: radius);
  }

  Future<void> _reSearchThisArea() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    final lat = cam.target.latitude;
    final lng = cam.target.longitude;
    final radius = await _getVisibleRadiusMeters();
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    setState(() => _showReSearchButton = false);
    ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
  }

  Future<Map<PlaceSource, NOverlayImage>> _getMarkerIcons() async {
    if (_markerIcons != null) return _markerIcons!;

    final normalIcon = await NOverlayImage.fromWidget(
      widget: const MapMarkerDot(color: Color(0xFF03C75A)),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return {};

    final bothIcon = await NOverlayImage.fromWidget(
      widget: const MapMarkerDot(color: Color(0xFFFFAB00), star: true),
      size: const Size(32, 32),
      context: context,
    );
    if (!mounted) return {};

    _markerIcons = {
      PlaceSource.tourApi: normalIcon,
      PlaceSource.kakaoLocal: normalIcon,
      PlaceSource.both: bothIcon,
    };
    return _markerIcons!;
  }

  // Phase 5: Grid clustering
  List<_Cluster> _clusterPlaces(List<PlaceEntity> places, double zoom) {
    final cellDeg = zoom >= 14 ? 0.002 : zoom >= 12 ? 0.01 : 0.05;
    final groups = <String, List<PlaceEntity>>{};
    for (final p in places) {
      final gx = (p.longitude / cellDeg).floor();
      final gy = (p.latitude / cellDeg).floor();
      groups.putIfAbsent('$gx,$gy', () => []).add(p);
    }
    return groups.values.map((pts) {
      final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      return _Cluster(NLatLng(lat, lng), pts);
    }).toList();
  }

  Future<NOverlayImage> _getClusterIcon(int count) async {
    if (_clusterIconCache.containsKey(count)) return _clusterIconCache[count]!;
    final icon = await NOverlayImage.fromWidget(
      widget: _ClusterDot(count: count),
      size: const Size(40, 40),
      context: context,
    );
    _clusterIconCache[count] = icon;
    return icon;
  }

  Future<void> _updateExploreMarkers(List<PlaceEntity> places) async {
    if (_ctrl == null) return;
    await _ctrl!.clearOverlays(type: NOverlayType.marker);
    if (places.isEmpty) return;

    final clusters = _clusterPlaces(places, _currentZoom);
    final icons = await _getMarkerIcons();
    if (!mounted) return;

    final markers = <NMarker>{};

    for (int ci = 0; ci < clusters.length; ci++) {
      final cluster = clusters[ci];
      if (cluster.places.length > 1) {
        // Cluster marker
        final clusterIcon = await _getClusterIcon(cluster.places.length);
        if (!mounted) return;
        final marker = NMarker(
          id: 'cluster_$ci',
          position: cluster.center,
          icon: clusterIcon,
        );
        marker.setOnTapListener((_) async {
          final clusterPts =
              cluster.places.map((p) => NLatLng(p.latitude, p.longitude)).toList();
          final ctrl = _ctrl;
          if (ctrl == null) return;
          await MapCameraUtils.fitPoints(
            ctrl,
            clusterPts,
            padding: const EdgeInsets.all(80),
          );
          // zoom in one level
          final newCam = await ctrl.getCameraPosition();
          await ctrl.updateCamera(
            NCameraUpdate.withParams(zoom: (newCam.zoom + 1).clamp(1.0, 21.0)),
          );
        });
        markers.add(marker);
      } else {
        // Single marker
        final place = cluster.places.first;
        final color = _sourceColor(place.source);
        final marker = NMarker(
          id: place.id,
          position: NLatLng(place.latitude, place.longitude),
          icon: icons[place.source],
          caption: NOverlayCaption(
            text: place.name,
            textSize: 12,
            color: color,
            haloColor: Colors.black87,
          ),
          captionOffset: 4,
          isHideCollidedCaptions: true,
        );
        marker.setOnTapListener((_) {
          ref.read(mapSearchNotifierProvider.notifier).selectPlace(place);
        });
        markers.add(marker);
      }
    }

    await _ctrl!.addOverlayAll(markers);
  }

  Color _sourceColor(PlaceSource source) => switch (source) {
        PlaceSource.tourApi => const Color(0xFF03C75A),
        PlaceSource.kakaoLocal => const Color(0xFF03C75A),
        PlaceSource.both => const Color(0xFFFFAB00),
      };

  double _topPanelHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 108;

  // ── Mode A helpers ────────────────────────────────────────────

  Future<void> _showLongPressSheet(NLatLng latLng) async {
    final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
    final locationName = address ?? '선택한 위치';
    if (!mounted) return;
    final modeAState = ref.read(modeAProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LongPressSheet(
        latLng: latLng,
        locationName: locationName,
        canAddWaypoint: modeAState.waypoints.length < 3,
        onSetOrigin: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setOriginGps(
                latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onSetDest: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setDestCoords(
                latLng.latitude, latLng.longitude, locationName);
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
        onAddWaypoint: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: locationName,
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              ));
          ref.read(mapModeProvider.notifier).set(MapMode.modeA);
        },
      ),
    );
  }

  Future<void> _onModeASearch() async {
    FocusScope.of(context).unfocus();
    await ref.read(modeAProvider.notifier).search();
    if (mounted && ref.read(modeAProvider).routeResult != null) {
      setState(() => _sheetAExpanded = false);
    }
  }

  void _showRerouteDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: kMapPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '경로를 벗어났어요',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '현재 경로에서 60m 이상 벗어났습니다.\n계속 진행하시겠어요?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(modeANavProvider.notifier).stop();
            },
            child: const Text('안내 종료',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(modeANavProvider.notifier).dismissReroute();
            },
            child: const Text('계속 진행',
                style: TextStyle(
                    color: kMapGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showArrivalMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kMapGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('목적지에 도착했어요!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showWaypointCandidateSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WaypointCandidateSheet(
        state: ref.read(modeAProvider),
        onAdd: (candidate) {
          Navigator.pop(ctx);
          ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: candidate.name,
                latitude: candidate.latitude,
                longitude: candidate.longitude,
              ));
        },
        onLoadMore: (extra) =>
            ref.read(modeAProvider.notifier).loadWaypointCandidates(extra),
      ),
    );
  }

  // ── Mode B helpers ────────────────────────────────────────────

  Future<void> _updateModeBMarkers(List<TouristRouteEntity> routes) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);
    await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
    for (final r in routes.where((r) => r.hasCoordinate)) {
      await ctrl.addOverlay(NMarker(
        id: r.id,
        position: NLatLng(r.startLat!, r.startLng!),
      ));
    }
  }

  Future<void> _onModeBSearch() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final pos = _position;
    await ref.read(routeSearchProvider.notifier).loadRoutes(
          food,
          lat: pos?.latitude ?? 37.5635,
          lng: pos?.longitude ?? 126.9869,
        );
  }

  Future<void> _selectModeBRoute(int idx) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    final routes = ref.read(routeSearchProvider).routes;
    if (idx >= routes.length) return;
    final route = routes[idx];
    final ctrl = _ctrl;
    if (ctrl == null) return;

    if (route.hasCoordinate) {
      await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
      await ctrl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(route.startLat!, route.startLng!),
          zoom: 14,
        ),
      );
      if (route.hasImages && mounted) {
        _showImageGallery(context, route);
      }
    } else {
      await ctrl.clearOverlays(type: NOverlayType.polylineOverlay);
      if (route.gpxpath == null) return;
      setState(() => _gpxLoading = true);
      try {
        final points = await _fetchGpxPoints(route.gpxpath!);
        if (!mounted || points.length < 2) return;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'route_path',
          coords: points,
          color: const Color(0xFF03C75A),
          width: 5,
        ));
        await _fitCamera(ctrl, points);
      } finally {
        if (mounted) setState(() => _gpxLoading = false);
      }
    }
  }

  Future<List<NLatLng>> _fetchGpxPoints(String gpxUrl) async {
    try {
      final res = await http
          .get(Uri.parse(gpxUrl))
          .timeout(const Duration(seconds: 15));
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

  Future<void> _fitCamera(NaverMapController ctrl, List<NLatLng> points) async {
    await MapCameraUtils.fitPoints(ctrl, points);
  }

  double _modeBTopBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;

  // ── Zoom controls builder ─────────────────────────────────────

  Widget _buildZoomControls(
    BuildContext context,
    MapMode mode,
    double bottomPad,
    ModeAState modeAState,
  ) {
    if (mode == MapMode.modeB) {
      return AnimatedBuilder(
        animation: _sheetBCtrl,
        builder: (context, child) {
          final screenH = MediaQuery.sizeOf(context).height;
          final sheetH = _sheetBCtrl.isAttached
              ? _sheetBCtrl.size * screenH
              : screenH * 0.46;
          return Positioned(
            right: 12,
            bottom: sheetH + 16,
            child: child!,
          );
        },
        child: MapZoomControls(
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onLocation: _goToCurrentLocation,
          isLocating: _locating,
        ),
      );
    }

    if (mode == MapMode.modeA && modeAState.routeResult != null) {
      return Positioned(
        right: 12,
        bottom: (modeAState.routeResult != null
                ? context.screenHeight * (_sheetAExpanded ? 0.82 : 0.52)
                : 0) +
            bottomPad +
            16,
        child: MapZoomControls(
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onLocation: _goToCurrentLocation,
          isLocating: _locating,
        ),
      );
    }

    return Positioned(
      right: 12,
      bottom: bottomPad + 16,
      child: MapZoomControls(
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onLocation: _goToCurrentLocation,
        isLocating: _locating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final mode = ref.watch(mapModeProvider);
    final exploreState = ref.watch(mapSearchNotifierProvider);
    final modeAState = ref.watch(modeAProvider);
    final navState = ref.watch(modeANavProvider);
    final food = ref.watch(selectedFoodProvider);
    final modeBState = ref.watch(routeSearchProvider);
    final profileAsync = ref.watch(userProfileProvider);

    // Mode change listener
    ref.listen<MapMode>(mapModeProvider, _onModeChanged);

    // Explore: sync markers when places change
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

    // Mode A: sync markers + polyline when state changes
    ref.listen<ModeAState>(modeAProvider, (prev, next) {
      final coordsChanged = prev?.originLat != next.originLat ||
          prev?.originLng != next.originLng ||
          prev?.destLat != next.destLat ||
          prev?.destLng != next.destLng ||
          prev?.waypoints.length != next.waypoints.length;
      if (coordsChanged) {
        _syncModeAMarkers(next);
        // 목적지 초기화 시 폴리라인도 지운다
        if (next.destLat == null) _drawModeAPolyline(null);
      }

      // 경로 결과 생성/변경 시 폴리라인 그리기
      if (prev?.routeResult != next.routeResult) {
        _drawModeAPolyline(next.routeResult);
      }
    });

    // Mode B: update markers when routes change
    ref.listen<RouteSearchState>(routeSearchProvider, (prev, next) {
      if (!next.isLoading && next.routes != prev?.routes) {
        _updateModeBMarkers(next.routes);
      }
    });

    // Phase 6: navigation listener
    ref.listen<ModeANavState>(modeANavProvider, (prev, next) {
      if (next.showReroutePrompt && !(prev?.showReroutePrompt ?? false)) {
        _showRerouteDialog();
      }
      // Arrived
      if ((prev?.isNavigating ?? false) &&
          next.isNavigating &&
          next.remainingDistanceM < 50) {
        ref.read(modeANavProvider.notifier).stop();
        _showArrivalMessage();
      }
    });

    final categories = [
      '전체',
      ...?profileAsync.valueOrNull?.preferredCategories,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Explore top panel ──────────────────────────────────
        if (mode == MapMode.explore)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _ExploreTopPanel(
              searchController: _searchCtrl,
              categories: categories,
              selectedCategory: exploreState.selectedCategory,
              onClose: () => context.pop(),
              onSearch: _onSearchSubmit,
              onCategoryTap: (cat) async {
                final radius = await _getVisibleRadiusMeters();
                if (!mounted) return;
                ref
                    .read(mapSearchNotifierProvider.notifier)
                    .selectCategory(cat, radiusMeters: radius);
              },
            ),
          ),

        // ── Mode A route panel ─────────────────────────────────
        if (mode == MapMode.modeA)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _ModeARoutePanel(
              state: modeAState,
              locating: _locating,
              onTapOrigin: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.explore),
              onGpsOrigin: _fetchGpsOriginForModeA,
              onTapDest: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.explore),
              onClearDest: () =>
                  ref.read(modeAProvider.notifier).setDestCoords(null, null, ''),
              onSetTransport: (t) =>
                  ref.read(modeAProvider.notifier).setTransport(t),
              onRemoveWaypoint: (i) =>
                  ref.read(modeAProvider.notifier).removeWaypoint(i),
              onReorderWaypoints: (oldIdx, newIdx) =>
                  ref.read(modeAProvider.notifier).reorderWaypoint(oldIdx, newIdx),
              onSearch: (modeAState.originLat == null || modeAState.to.isEmpty)
                  ? null
                  : _onModeASearch,
              onBack: () => context.pop(),
            ),
          ),

        // ── Mode B top bar (food != null) ──────────────────────
        if (mode == MapMode.modeB && food != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _ModeBTopBar(
              food: food,
              onBack: () => context.pop(),
            ),
          ),

        // ── Explore: loading chip ──────────────────────────────
        if (mode == MapMode.explore && exploreState.isLoading)
          Positioned(
            top: _topPanelHeight(context) + 12,
            left: 0, right: 0,
            child: const Center(child: MapLoadingChip('맛집 불러오는 중...')),
          ),

        // ── Explore: re-search button ──────────────────────────
        if (mode == MapMode.explore && _showReSearchButton && !exploreState.isLoading)
          Positioned(
            top: _topPanelHeight(context) + 12,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _reSearchThisArea,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: _kPanel,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 15, color: Colors.white70),
                      SizedBox(width: 6),
                      Text('이 지역 재검색',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Explore: legend ────────────────────────────────────
        if (mode == MapMode.explore && exploreState.places.isNotEmpty)
          Positioned(
            right: 12,
            top: _topPanelHeight(context) + 12,
            child: const _MapLegend(),
          ),

        // ── Mode A: kcal widget ────────────────────────────────
        if (mode == MapMode.modeA)
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 220,
            child: _KcalWidget(routeKcal: modeAState.routeResult?.kcalBurn),
          ),

        // ── Mode A: result sheet ───────────────────────────────
        if (mode == MapMode.modeA && modeAState.routeResult != null)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: _sheetAExpanded
                  ? context.screenHeight * 0.82
                  : context.screenHeight * 0.52,
              decoration: const BoxDecoration(
                color: kMapPanel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 40,
                      offset: Offset(0, -12)),
                ],
              ),
              child: _ModeAResultSheet(
                state: modeAState,
                expanded: _sheetAExpanded,
                onToggleExpand: () =>
                    setState(() => _sheetAExpanded = !_sheetAExpanded),
                onRestaurantTap: (id) => context.push('/restaurant/$id'),
                onStartNavigation: () => ref.read(modeANavProvider.notifier)
                    .start(modeAState.routeResult!),
                onLoadCandidates: (extra) =>
                    ref.read(modeAProvider.notifier).loadWaypointCandidates(extra),
                onAddWaypointCandidate: (candidate) {
                  ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                    name: candidate.name,
                    latitude: candidate.latitude,
                    longitude: candidate.longitude,
                  ));
                  _showWaypointCandidateSheet(context);
                },
              ),
            ),
          ),

        // ── Phase 6: Navigation banner ─────────────────────────
        if (mode == MapMode.modeA && navState.isNavigating)
          Positioned(
            left: 0, right: 0,
            bottom: context.screenHeight * (_sheetAExpanded ? 0.82 : 0.52),
            child: _NavBanner(
              navState: navState,
              onStop: () => ref.read(modeANavProvider.notifier).stop(),
            ),
          ),

        // ── Mode A: loading overlay ────────────────────────────
        if (mode == MapMode.modeA && modeAState.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(
                    color: kMapGreen, strokeWidth: 2),
              ),
            ),
          ),

        // ── Mode B: GPX loading chip ───────────────────────────
        if (mode == MapMode.modeB && _gpxLoading)
          Positioned(
            top: _modeBTopBarHeight(context) + 12,
            left: 0, right: 0,
            child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
          ),

        // ── Mode B: DraggableScrollableSheet ──────────────────
        if (mode == MapMode.modeB && food != null)
          DraggableScrollableSheet(
            controller: _sheetBCtrl,
            initialChildSize: 0.46,
            minChildSize: 0.13,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.13, 0.46, 0.80],
            builder: (context, scrollController) => _ModeBBottomPanel(
              scrollController: scrollController,
              state: modeBState,
              food: food,
              pos: _position,
              isLocating: _locating,
              onSearch: _onModeBSearch,
              onTransportChange: (v) {
                final notifier = ref.read(routeSearchProvider.notifier);
                notifier.setTransport(
                  v, food,
                  lat: _position?.latitude ?? 37.5635,
                  lng: _position?.longitude ?? 126.9869,
                );
                _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
              },
              onSelectRoute: _selectModeBRoute,
              onStartTap: () => context.go('/record'),
            ),
          ),

        // ── Zoom controls ──────────────────────────────────────
        _buildZoomControls(context, mode, bottomPad, modeAState),

        // ── Mode toggle (탐색 ↔ 경로) — hidden in modeB ──────
        if (mode != MapMode.modeB)
          Positioned(
            left: 12,
            bottom: bottomPad + 16,
            child: _ModeToggle(
              mode: mode,
              onExplore: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.explore),
              onModeA: () {
                ref.read(mapModeProvider.notifier).set(MapMode.modeA);
                final st = ref.read(modeAProvider);
                if (st.originLat == null) {
                  _fetchGpsOriginForModeA();
                }
              },
            ),
          ),

        // ── Explore: place bottom sheet ────────────────────────
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
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Explore widgets ──────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ExploreTopPanel extends StatelessWidget {
  const _ExploreTopPanel({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.onClose,
    required this.onSearch,
    required this.onCategoryTap,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final VoidCallback onClose;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  MapControlButton(
                    onTap: onClose,
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: _kWhite87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kPanelAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: onSearch,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '음식점, 관광지, 백화점 검색',
                          hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                              fontWeight: FontWeight.w400),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: _kWhite45),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded,
                                size: 18, color: _kWhite45),
                            onPressed: () => onSearch(searchController.text),
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03C75A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NAVER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF03C75A),
                          letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => onCategoryTap(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : _kPanelAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black87
                              : const Color(0xFFAEAEB2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kPanel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(color: Color(0xFF03C75A), label: '장소'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFFFAB00), label: '⭐ 추천'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kWhite87)),
      ],
    );
  }
}

class _ExplorePlaceSheet extends StatelessWidget {
  const _ExplorePlaceSheet({
    required this.place,
    required this.onClose,
    required this.canAddWaypoint,
    required this.onSetOrigin,
    required this.onSetDest,
    required this.onAddWaypoint,
  });
  final PlaceEntity place;
  final bool canAddWaypoint;
  final VoidCallback onClose;
  final ValueChanged<PlaceEntity> onSetOrigin;
  final ValueChanged<PlaceEntity> onSetDest;
  final ValueChanged<PlaceEntity> onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (place.source) {
      PlaceSource.tourApi => ('장소', const Color(0xFF03C75A)),
      PlaceSource.kakaoLocal => ('장소', const Color(0xFF03C75A)),
      PlaceSource.both => ('⭐ 추천', const Color(0xFFFFAB00)),
    };

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sourceLabel.$2.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sourceLabel.$1,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: sourceLabel.$2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (place.category != null &&
                        place.category!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.category!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (place.address != null &&
                        place.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: _kWhite45),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.address!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (place.phone != null && place.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 15, color: _kWhite45),
                          const SizedBox(width: 4),
                          Text(
                            place.phone!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _PlaceRouteBtn(
                          label: '출발지',
                          color: const Color(0xFF2ECC71),
                          onTap: () => onSetOrigin(place),
                        ),
                        const SizedBox(width: 8),
                        _PlaceRouteBtn(
                          label: '도착지',
                          color: const Color(0xFFE74C3C),
                          onTap: () => onSetDest(place),
                        ),
                        if (canAddWaypoint) ...[
                          const SizedBox(width: 8),
                          _PlaceRouteBtn(
                            label: '경유지',
                            color: const Color(0xFFF39C12),
                            onTap: () => onAddWaypoint(place),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRouteBtn extends StatelessWidget {
  const _PlaceRouteBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode A widgets ────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

// ─── Mode A 경로 입력 패널 ────────────────────────────────────────────────────
//
// 출발지·도착지·경유지는 모두 읽기 전용 텍스트.
// • 탭 → 탐색탭(explore)으로 이동해 장소를 검색·선택하면 자동 복귀
// • 출발지 옆 GPS 버튼 → 현재 위치 자동 설정
// • 경유지는 drag handle(꾹 누르기)로 순서 변경 가능
// • 경유지 추가: 지도 롱프레스 또는 탐색탭에서 "+ 경유지" 선택

class _ModeARoutePanel extends StatelessWidget {
  const _ModeARoutePanel({
    required this.state,
    required this.locating,
    required this.onTapOrigin,
    required this.onGpsOrigin,
    required this.onTapDest,
    required this.onClearDest,
    required this.onSetTransport,
    required this.onRemoveWaypoint,
    required this.onReorderWaypoints,
    required this.onSearch,
    required this.onBack,
  });

  final ModeAState state;
  final bool locating;
  final VoidCallback onTapOrigin;
  final VoidCallback onGpsOrigin;
  final VoidCallback onTapDest;
  final VoidCallback onClearDest;
  final ValueChanged<String> onSetTransport;
  final ValueChanged<int> onRemoveWaypoint;
  final void Function(int oldIdx, int newIdx) onReorderWaypoints;
  final VoidCallback? onSearch;
  final VoidCallback onBack;

  static const _transports = [
    ('walk', '도보', Icons.directions_walk_rounded),
    ('bike', '자전거', Icons.directions_bike_rounded),
    ('transit', '대중교통', Icons.directions_bus_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 헤더: 뒤로가기 + 타이틀 ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: Row(
                children: [
                  MapControlButton(
                    onTap: onBack,
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: kMapWhite87),
                  ),
                  const SizedBox(width: 10),
                  const Text('경로 찾기',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kMapWhite87)),
                ],
              ),
            ),

            // ── 경유지 포함 입력 필드 컨테이너 ───────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // 출발지 (읽기 전용 + GPS 버튼)
                  MapFieldRow(
                    dot: const MapWaypointDot(type: MapWaypointDotType.origin),
                    child: locating
                        ? const Row(children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kMapWhite45),
                            ),
                            SizedBox(width: 8),
                            Text('위치 확인 중...',
                                style: TextStyle(
                                    color: kMapWhite45,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ])
                        : Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: onTapOrigin,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  state.from.isEmpty
                                      ? '출발지를 설정해주세요'
                                      : state.from,
                                  style: TextStyle(
                                    color: state.from.isEmpty
                                        ? kMapWhite45
                                        : kMapWhite87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: onGpsOrigin,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.my_location_rounded,
                                    size: 18, color: kMapWhite45),
                              ),
                            ),
                          ]),
                  ),

                  const Divider(color: Colors.white12, height: 1, indent: 16),

                  // 도착지 (읽기 전용 + 지우기 버튼)
                  MapFieldRow(
                    dot: const MapWaypointDot(type: MapWaypointDotType.dest),
                    child: GestureDetector(
                      onTap: onTapDest,
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            state.to.isEmpty ? '어디로 갈까요?' : state.to,
                            style: TextStyle(
                              color: state.to.isEmpty
                                  ? kMapWhite45
                                  : kMapWhite87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (state.to.isNotEmpty)
                          GestureDetector(
                            onTap: onClearDest,
                            child: const Icon(Icons.cancel_rounded,
                                size: 16, color: kMapWhite45),
                          ),
                      ]),
                    ),
                  ),

                  // 경유지 목록 (drag-to-reorder)
                  if (state.waypoints.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.waypoints.length,
                      onReorderItem: onReorderWaypoints,
                      buildDefaultDragHandles: false,
                      itemBuilder: (ctx, i) {
                        final wp = state.waypoints[i];
                        return Column(
                          key: ValueKey('wp_$i'),
                          children: [
                            const Divider(
                                color: Colors.white12, height: 1, indent: 16),
                            MapFieldRow(
                              dot: const MapWaypointDot(
                                  type: MapWaypointDotType.waypoint),
                              child: Row(children: [
                                Expanded(
                                  child: Text(wp.name,
                                      style: const TextStyle(
                                          color: kMapWhite87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.drag_handle_rounded,
                                        size: 18, color: kMapWhite45),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => onRemoveWaypoint(i),
                                  child: const Icon(Icons.close_rounded,
                                      size: 16, color: kMapWhite45),
                                ),
                              ]),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── 이동수단 + 코스 생성 버튼 ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  ..._transports.map((t) {
                    final (id, label, icon) = t;
                    final on = state.transport == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: GestureDetector(
                        onTap: () => onSetTransport(id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: on
                                ? kMapGreen.withValues(alpha: 0.9)
                                : kMapPanelAlt,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: on ? kMapGreen : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  size: 13,
                                  color: on ? Colors.white : kMapWhite45),
                              const SizedBox(width: 3),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: on ? Colors.white : kMapWhite45)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // 코스 생성 버튼
                  GestureDetector(
                    onTap: onSearch,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: onSearch != null ? kMapGreen : kMapPanelAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded,
                              size: 14,
                              color: onSearch != null
                                  ? Colors.white
                                  : kMapWhite45),
                          const SizedBox(width: 5),
                          Text(
                            '코스 생성',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: onSearch != null
                                  ? Colors.white
                                  : kMapWhite45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeAResultSheet extends StatelessWidget {
  const _ModeAResultSheet({
    required this.state,
    required this.expanded,
    required this.onToggleExpand,
    required this.onRestaurantTap,
    required this.onStartNavigation,
    required this.onLoadCandidates,
    required this.onAddWaypointCandidate,
  });

  final ModeAState state;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onRestaurantTap;
  final VoidCallback onStartNavigation;
  final ValueChanged<int> onLoadCandidates;
  final ValueChanged<WaypointCandidateEntity> onAddWaypointCandidate;

  @override
  Widget build(BuildContext context) {
    final result = state.routeResult!;

    return Column(
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: const MapSheetHandle(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.wp(5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('예상 소모',
                          style: TextStyle(
                              fontSize: 11,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${result.kcalBurn}',
                            style: TextStyle(
                                fontSize: context.wp(10.5),
                                fontWeight: FontWeight.w800,
                                color: kMapGreen,
                                letterSpacing: -1.5,
                                height: 1),
                          ),
                          const SizedBox(width: 4),
                          const Text('kcal',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kMapWhite45)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${result.distanceKm} km · ${result.durationMinutes}분',
                        style: const TextStyle(
                            fontSize: 11,
                            color: kMapWhite45,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.fromName} → ${result.toName}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: kMapWhite87,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              if (result.waypoints.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: result.waypoints
                      .map((w) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kMapGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '경유 ${w.name}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kMapGreen,
                                  fontWeight: FontWeight.w700),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        // ── Phase 3: calorie comparison (목적지가 음식점/카페인 경우) ──
        if (state.destIsRestaurant && state.destKcal > 0) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(context.wp(5), 14, context.wp(5), 0),
            child: _CalorieComparePanel(
              routeKcal: result.kcalBurn,
              destKcal: state.destKcal,
              onAddWaypoint: () {
                final gap = state.destKcal - result.kcalBurn;
                if (gap > 0) onLoadCandidates(gap);
              },
            ),
          ),
        ] else ...[
          Padding(
            padding: EdgeInsets.fromLTRB(context.wp(5), 14, context.wp(5), 4),
            child: const Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('도착지 근처 추천 맛집',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kMapWhite87)),
                    Text('소모 칼로리 ±20% 범위에서 추천',
                        style: TextStyle(
                            fontSize: 11,
                            color: kMapWhite45,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: state.restaurants.isEmpty
                ? const Center(
                    child: Text('추천 식당이 없습니다',
                        style: TextStyle(color: kMapWhite45, fontSize: 13)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        context.wp(5), 4, context.wp(5), 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.restaurants.length,
                    itemBuilder: (ctx, i) {
                      final r = state.restaurants[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: context.wp(58),
                          child: _RestaurantCard(
                            restaurant: r,
                            routeKcal: result.kcalBurn,
                            onTap: () => onRestaurantTap(r.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],

        // ── Phase 6: 안내 시작 버튼 ────────────────────────────
        if (result.routePoints.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.wp(5), 8, context.wp(5), 12),
              child: GestureDetector(
                onTap: onStartNavigation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: kMapGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded,
                          size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('안내 시작',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _CalMatch { good, tooMuch, tooLittle }

_CalMatch _calMatch(int rKcal, int routeKcal) {
  if (routeKcal <= 0) return _CalMatch.good;
  final ratio = rKcal / routeKcal;
  if (ratio >= 0.80 && ratio <= 1.20) return _CalMatch.good;
  return ratio > 1.20 ? _CalMatch.tooMuch : _CalMatch.tooLittle;
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.routeKcal,
    required this.onTap,
  });

  final RestaurantEntity restaurant;
  final int routeKcal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final match = _calMatch(r.kcal, routeKcal);
    final ratio = routeKcal > 0 ? r.kcal / routeKcal : 1.0;
    final matchPct = (100 - (1 - ratio).abs() * 100).clamp(0.0, 100.0);
    final matchColor = match == _CalMatch.good
        ? kMapGreen
        : match == _CalMatch.tooMuch
            ? const Color(0xFFFFB547)
            : const Color(0xFF7C8AFF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kMapPanelAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImageWidget(
              type: FoodImageWidget.fromString(r.imageType),
              height: 100,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: const TextStyle(
                                color: kMapWhite87,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: -0.1),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      TinyRing(
                          pct: matchPct,
                          size: 30,
                          color: matchColor,
                          label: '${matchPct.round()}'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${r.menu} · ${r.kcal} kcal',
                      style: const TextStyle(
                          color: kMapWhite45,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      match == _CalMatch.good
                          ? '딱 맞아요 ✓'
                          : match == _CalMatch.tooMuch
                              ? '더 움직여야 해요'
                              : '여유 있어요',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: matchColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFFFC56E)),
                      const SizedBox(width: 3),
                      Text(r.rating.toString(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kMapWhite87)),
                      Text(' · ${r.distanceLabel} · ${r.walkLabel}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LongPressSheet extends StatelessWidget {
  const _LongPressSheet({
    required this.latLng,
    required this.locationName,
    required this.canAddWaypoint,
    required this.onSetOrigin,
    required this.onSetDest,
    required this.onAddWaypoint,
  });

  final NLatLng latLng;
  final String locationName;
  final bool canAddWaypoint;
  final VoidCallback onSetOrigin;
  final VoidCallback onSetDest;
  final VoidCallback onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kMapHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            locationName,
            style: const TextStyle(
                color: kMapWhite87, fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text(
            '이 위치를 어디로 설정할까요?',
            style: TextStyle(
                color: kMapWhite87, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              MapLocationActionBtn(
                  label: '출발지',
                  icon: Icons.trip_origin_rounded,
                  color: const Color(0xFF7C8AFF),
                  onTap: onSetOrigin),
              const SizedBox(width: 8),
              MapLocationActionBtn(
                  label: '도착지',
                  icon: Icons.place_rounded,
                  color: const Color(0xFFFF4D6D),
                  onTap: onSetDest),
              if (canAddWaypoint) ...[
                const SizedBox(width: 8),
                MapLocationActionBtn(
                    label: '경유지',
                    icon: Icons.add_location_alt_rounded,
                    color: const Color(0xFFFFC56E),
                    onTap: onAddWaypoint),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KcalWidget extends ConsumerWidget {
  const _KcalWidget({this.routeKcal});
  final int? routeKcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walk = ref.watch(walkSessionProvider);
    return GestureDetector(
      onTap: () => context.push('/record'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥 오늘',
                style: TextStyle(
                    fontSize: 10,
                    color: kMapWhite45,
                    fontWeight: FontWeight.w600)),
            Text(
              '${walk.caloriesKcal.round()} kcal',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF7A45)),
            ),
            if (routeKcal != null)
              Text(
                '+$routeKcal 예상',
                style: const TextStyle(
                    fontSize: 10,
                    color: kMapGreen,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Phase 3: Calorie compare panel ───────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _CalorieComparePanel extends StatelessWidget {
  const _CalorieComparePanel({
    required this.routeKcal,
    required this.destKcal,
    required this.onAddWaypoint,
  });

  final int routeKcal;
  final int destKcal;
  final VoidCallback onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final gap = destKcal - routeKcal;
    final isGood = gap.abs() <= (destKcal * AppConstants.kcalMatchTolerancePct).round();
    final needMore = gap > 0;

    final routeRatio = (routeKcal / destKcal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('칼로리 비교',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMapWhite87)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isGood
                      ? kMapGreen.withValues(alpha: 0.2)
                      : const Color(0xFFFFB547).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGood
                      ? '딱 맞아요 ✓'
                      : needMore
                          ? '$gap kcal 더 필요'
                          : '${-gap} kcal 여유',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isGood
                        ? kMapGreen
                        : const Color(0xFFFFB547),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 경로 칼로리 바
          _KcalBar(
            label: '경로 소모',
            kcal: routeKcal,
            ratio: routeRatio,
            color: kMapGreen,
          ),
          const SizedBox(height: 6),
          // 목적지 음식 칼로리 바
          _KcalBar(
            label: '음식 칼로리',
            kcal: destKcal,
            ratio: 1.0,
            color: const Color(0xFFFFB547),
          ),
          if (!isGood && needMore) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAddWaypoint,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB547).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFB547).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_location_alt_rounded,
                        size: 15, color: Color(0xFFFFB547)),
                    SizedBox(width: 6),
                    Text('경유지 추가로 더 움직이기',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFB547))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KcalBar extends StatelessWidget {
  const _KcalBar({
    required this.label,
    required this.kcal,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int kcal;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
            Text('$kcal kcal',
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, constraints) {
          return Stack(
            children: [
              Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                height: 6,
                width: constraints.maxWidth * ratio,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Phase 4: Waypoint candidate sheet ────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _WaypointCandidateSheet extends StatelessWidget {
  const _WaypointCandidateSheet({
    required this.state,
    required this.onAdd,
    required this.onLoadMore,
  });

  final ModeAState state;
  final ValueChanged<WaypointCandidateEntity> onAdd;
  final ValueChanged<int> onLoadMore;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: kMapHandle, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('경유지 추천',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kMapWhite87)),
          const SizedBox(height: 4),
          const Text('경유하면 칼로리를 더 소모할 수 있는 장소예요',
              style: TextStyle(
                  fontSize: 12, color: kMapWhite45, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          if (state.loadingCandidates)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: kMapGreen, strokeWidth: 2),
              ),
            )
          else if (state.waypointCandidates.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('추천 경유지가 없습니다',
                    style: TextStyle(color: kMapWhite45, fontSize: 13)),
              ),
            )
          else
            ...state.waypointCandidates.map((c) => _WaypointCandidateCard(
                  candidate: c,
                  canAdd: state.waypoints.length < 3,
                  onAdd: () => onAdd(c),
                )),
        ],
      ),
    );
  }
}

class _WaypointCandidateCard extends StatelessWidget {
  const _WaypointCandidateCard({
    required this.candidate,
    required this.canAdd,
    required this.onAdd,
  });

  final WaypointCandidateEntity candidate;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // 이미지 or 아이콘
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: candidate.imageUrl != null
                ? SizedBox(
                    width: 54,
                    height: 54,
                    child: Image.network(
                      candidate.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(),
                    ),
                  )
                : _placeholderIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kMapGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(candidate.category,
                          style: const TextStyle(
                              fontSize: 10,
                              color: kMapGreen,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(candidate.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kMapWhite87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(candidate.detourLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: kMapWhite45,
                        fontWeight: FontWeight.w500)),
                Text('+${candidate.extraKcal} kcal 추가 소모',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFFB547),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canAdd)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: kMapGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kMapGreen.withValues(alpha: 0.5)),
                ),
                child: const Text('+ 경유지 추가',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kMapGreen)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.landscape_rounded, size: 24, color: kMapWhite45),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Phase 5: Cluster dot widget ───────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ClusterDot extends StatelessWidget {
  const _ClusterDot({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF03C75A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Phase 5: Cluster data class ───────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _Cluster {
  const _Cluster(this.center, this.places);
  final NLatLng center;
  final List<PlaceEntity> places;
}

// ════════════════════════════════════════════════════════════════════════════
// ── Phase 6: Navigation banner ────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavBanner extends StatelessWidget {
  const _NavBanner({required this.navState, required this.onStop});

  final ModeANavState navState;
  final VoidCallback onStop;

  IconData get _turnIcon => switch (navState.nextGuide?.type ?? 11) {
        12 => Icons.turn_right_rounded,
        13 => Icons.turn_left_rounded,
        14 => Icons.u_turn_left_rounded,
        100 => Icons.flag_rounded,
        _ => Icons.straight_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMapGreen.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Turn icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kMapGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_turnIcon, size: 24, color: kMapGreen),
          ),
          const SizedBox(width: 12),
          // Guide text + remaining
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  navState.nextGuide?.guidance ?? '경로를 따라 이동하세요',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMapWhite87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${navState.remainingLabel} 남음 · ${navState.remainingMinutes}분',
                  style: const TextStyle(
                      fontSize: 11,
                      color: kMapWhite45,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stop button
          GestureDetector(
            onTap: onStop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: const Text('종료',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B widgets ────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeBTopBar extends StatelessWidget {
  const _ModeBTopBar({
    required this.food,
    required this.onBack,
  });

  final FoodEntity food;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        boxShadow: [
          BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(
            children: [
              MapControlButton(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: _kWhite87),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPanelAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(food.emoji,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('내 주변 산책로',
                            style: TextStyle(
                                fontSize: 10,
                                color: _kWhite45,
                                fontWeight: FontWeight.w700)),
                        Text(
                          '${food.name} · ${food.kcal} kcal',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kWhite87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBBottomPanel extends StatelessWidget {
  const _ModeBBottomPanel({
    required this.scrollController,
    required this.state,
    required this.food,
    required this.pos,
    required this.isLocating,
    required this.onSearch,
    required this.onTransportChange,
    required this.onSelectRoute,
    required this.onStartTap,
  });

  final ScrollController scrollController;
  final RouteSearchState state;
  final FoodEntity food;
  final Position? pos;
  final bool isLocating;
  final VoidCallback onSearch;
  final void Function(String) onTransportChange;
  final void Function(int) onSelectRoute;
  final VoidCallback onStartTap;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedRoute;
    final hasRoutes = state.routes.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: _kPanel,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kHandle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasRoutes) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.wp(4)),
                      child: _TransportToggle(
                        value: state.transport,
                        onChanged: onTransportChange,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (isLocating)
              const SliverFillRemaining(
                child: Center(
                  child: Text('위치를 확인하는 중...',
                      style: TextStyle(
                          color: _kWhite45,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              )
            else if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF03C75A), strokeWidth: 2),
                ),
              )
            else if (state.routes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_outlined,
                          size: 36, color: _kWhite45),
                      const SizedBox(height: 12),
                      const Text(
                        '현재 위치 주변 코스를 찾아보세요',
                        style: TextStyle(
                            color: _kWhite45,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03C75A),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('주변 코스 검색',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pos != null
                            ? '현재 위치 기준으로 검색합니다'
                            : 'GPS 권한이 없어 기본 위치를 사용합니다',
                        style: const TextStyle(
                            fontSize: 11, color: _kWhite45),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RouteCard(
                      route: state.routes[i],
                      transport: state.transport,
                      isSelected: i == state.selectedRouteIdx,
                      onTap: () => onSelectRoute(i),
                    ),
                    childCount: state.routes.length,
                  ),
                ),
              ),
            if (selected != null)
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        context.wp(4), 4, context.wp(4), 8),
                    child: GestureDetector(
                      onTap: onStartTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF03C75A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation_rounded,
                                size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('이 코스로 시작하기',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransportToggle extends StatelessWidget {
  const _TransportToggle({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _kPanelAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleItem(
              label: '걷기',
              icon: Icons.directions_walk_rounded,
              selected: value == 'walk',
              onTap: () => onChanged('walk')),
          _ToggleItem(
              label: '자전거',
              icon: Icons.directions_bike_rounded,
              selected: value == 'bike',
              onTap: () => onChanged('bike')),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? _kPanel : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? _kWhite87 : _kWhite45),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? _kWhite87 : _kWhite45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.transport,
    required this.isSelected,
    required this.onTap,
  });

  final TouristRouteEntity route;
  final String transport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF03C75A).withValues(alpha: 0.12)
              : _kPanelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF03C75A) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  transport == 'walk'
                      ? Icons.hiking_rounded
                      : Icons.directions_bike_rounded,
                  size: 15,
                  color: isSelected
                      ? const Color(0xFF03C75A)
                      : _kWhite45,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    route.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? const Color(0xFF03C75A)
                          : _kWhite87,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (route.isLocal) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03C75A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('내 지역',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF03C75A),
                            fontWeight: FontWeight.w700)),
                  ),
                ] else if (route.region != null) ...[
                  const SizedBox(width: 6),
                  Text(route.region!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kWhite45,
                          fontWeight: FontWeight.w600)),
                ],
                if (route.gpxpath != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.route_rounded,
                      size: 13, color: _kWhite45),
                ],
                if (route.hasImages) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showImageGallery(context, route),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.photo_library_rounded,
                          size: 15, color: Color(0xFF03C75A)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (route.distanceFromUserM != null) ...[
                  MapInfoChip(
                    icon: Icons.near_me_rounded,
                    label: route.distanceFromUserM! < 1000
                        ? '${route.distanceFromUserM}m'
                        : '${(route.distanceFromUserM! / 1000).toStringAsFixed(1)}km',
                    color: const Color(0xFF03C75A),
                  ),
                  const SizedBox(width: 8),
                ],
                if (route.hasDetailInfo) ...[
                  MapInfoChip(
                    icon: Icons.straighten_rounded,
                    label: '${route.distanceKm.toStringAsFixed(1)}km',
                  ),
                  const SizedBox(width: 8),
                  MapInfoChip(
                    icon: Icons.schedule_rounded,
                    label: '${route.durationMinutes}분',
                  ),
                  const SizedBox(width: 8),
                  MapInfoChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '~${route.kcal}kcal',
                  ),
                ] else ...[
                  const MapInfoChip(
                    icon: Icons.info_outline_rounded,
                    label: '상세정보 없음',
                  ),
                ],
                if (route.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(route.tags.first,
                      style: const TextStyle(fontSize: 11, color: _kWhite45)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showImageGallery(BuildContext context, TouristRouteEntity route) {
  if (!route.hasImages) return;
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ImageGalleryDialog(route: route),
  );
}

class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({required this.route});
  final TouristRouteEntity route;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.route.imageUrls;
    final total = urls.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: _kPanel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.route.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kWhite87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: _kWhite45),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (ctx, i) => CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, __) => const ColoredBox(
                      color: _kPanelAlt,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white24),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: _kPanelAlt,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 32, color: _kWhite45),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < total; i++) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _current ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _current
                              ? const Color(0xFF03C75A)
                              : _kHandle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (i < total - 1) const SizedBox(width: 5),
                    ],
                    if (total > 1) ...[
                      const SizedBox(width: 12),
                      Text(
                        '${_current + 1} / $total',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _kWhite45,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode toggle ───────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onExplore,
    required this.onModeA,
  });

  final MapMode mode;
  final VoidCallback onExplore;
  final VoidCallback onModeA;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleTab(
            icon: Icons.explore_rounded,
            label: '탐색',
            active: mode == MapMode.explore,
            onTap: onExplore,
          ),
          _ToggleTab(
            icon: Icons.route_rounded,
            label: '경로',
            active: mode == MapMode.modeA,
            onTap: onModeA,
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kMapGreen.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : kMapWhite45),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : kMapWhite45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
