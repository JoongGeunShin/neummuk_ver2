import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../common/map_ui_atoms.dart';

const _kPanel    = kMapPanel;
const _kPanelAlt = kMapPanelAlt;
const _kHandle   = kMapHandle;
const _kWhite87  = kMapWhite87;
const _kWhite45  = kMapWhite45;

class ModeBOverlay extends ConsumerStatefulWidget {
  const ModeBOverlay({
    super.key,
    required this.controller,
    required this.events,
  });

  final NaverMapController? controller;
  final MapEventSink events;

  @override
  ConsumerState<ModeBOverlay> createState() => _ModeBOverlayState();
}

class _ModeBOverlayState extends ConsumerState<ModeBOverlay> {
  Position? _position;
  bool _locating = true;
  bool _gpxLoading = false;
  final _sheetController = DraggableScrollableController();

  Map<String, NOverlayImage>? _markerIcons;

  NaverMapController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didUpdateWidget(covariant ModeBOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller == null && widget.controller != null) {
      final pos = _position;
      if (pos != null) {
        _ctrl!.updateCamera(NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 13,
        ));
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // ── 마커 아이콘 캐시 ────────────────────────────────────────────

  Future<Map<String, NOverlayImage>> _getMarkerIcons() async {
    if (_markerIcons != null) return _markerIcons!;
    final walkIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFF03C75A), label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final bikeIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFFFB547), label: '●'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final selectedIcon = await NOverlayImage.fromWidget(
      widget: const MapRouteMarkerDot(color: Color(0xFFFFD700), label: '★'),
      size: const Size(32, 32),
      context: context,
    );
    if (!mounted) return {};
    _markerIcons = {'walk': walkIcon, 'bike': bikeIcon, 'selected': selectedIcon};
    return _markerIcons!;
  }

  // ── 마커 갱신 ─────────────────────────────────────────────────

  Future<void> _updateMapMarkers(
    List<TouristRouteEntity> routes, {
    int selectedIdx = -1,
  }) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await ctrl.clearOverlays(type: NOverlayType.marker);

    final icons = await _getMarkerIcons();
    if (!mounted) return;

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
          color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF03C75A),
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: true,
      ));
    }
  }

  // ── 위치 초기화 ────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final pos = await fetchMapPosition();
    if (!mounted) return;
    setState(() {
      _position = pos;
      _locating = false;
    });
    if (pos != null && _ctrl != null) {
      await _ctrl!.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(pos.latitude, pos.longitude),
        zoom: 13,
      ));
    }
    if (ref.read(routeSearchProvider).routes.isEmpty) {
      await _onSearch();
    }
  }

  // ── 코스 검색 ─────────────────────────────────────────────────

  Future<void> _onSearch() async {
    final food = ref.read(selectedFoodProvider);
    if (food == null) return;
    final pos = _position;
    await ref.read(routeSearchProvider.notifier).loadRoutes(
          food,
          lat: pos?.latitude ?? 37.5635,
          lng: pos?.longitude ?? 126.9869,
        );
  }

  // ── 카드 탭 → 선택 + 상세 ────────────────────────────────────

  Future<void> _onRouteCardTap(int idx, TouristRouteEntity route) async {
    ref.read(routeSearchProvider.notifier).selectRoute(idx);
    if (mounted) context.push('/place-detail', extra: route);
  }

  // ── 루트 선택 → GPX 로드 ──────────────────────────────────────

  Future<void> _onRouteSelected(int idx, List<TouristRouteEntity> routes) async {
    if (idx < 0 || idx >= routes.length) return;
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

    if (route.gpxpath != null) {
      setState(() => _gpxLoading = true);
      try {
        final points = await _fetchGpxPoints(route.gpxpath!);
        if (!mounted || points.length < 2) return;
        await ctrl.addOverlay(NPolylineOverlay(
          id: 'course_path',
          coords: points,
          color: route.type == '자전거'
              ? const Color(0xFFFFB547)
              : const Color(0xFF03C75A),
          width: 5,
        ));
        await _fitCamera(ctrl, points);
      } finally {
        if (mounted) setState(() => _gpxLoading = false);
      }
    }

    await _updateMapMarkers(routes, selectedIdx: idx);
  }

  // ── 코스 시작 → 현재위치~코스 시작점 접근 경로 ──────────────

  Future<void> _onCourseStarted(TouristRouteEntity route) async {
    final ctrl = _ctrl;
    final pos = _position;
    if (ctrl == null) return;

    // 시트 최소화
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.13,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 코스 시작점 좌표가 없으면 안내만
    if (!route.hasCoordinate || pos == null) {
      _showStartSnackbar(route);
      return;
    }

    // 현재 위치 → 코스 시작점 도보 경로 (Kakao Mobility)
    final approachPoints = await _fetchApproachRoute(
      fromLat: pos.latitude, fromLng: pos.longitude,
      toLat: route.startLat!, toLng: route.startLng!,
    );

    if (!mounted) return;

    if (approachPoints.isNotEmpty) {
      await ctrl.addOverlay(NPolylineOverlay(
        id: 'approach_path',
        coords: approachPoints,
        color: const Color(0xFF7C8AFF), // 보라 — 접근 경로
        width: 4,
      ));

      // 접근 경로 + 코스 전체 카메라 피팅
      final allPoints = [
        NLatLng(pos.latitude, pos.longitude),
        ...approachPoints,
        NLatLng(route.startLat!, route.startLng!),
      ];
      await _fitCamera(ctrl, allPoints, padding: const EdgeInsets.all(80));
    }

    _showStartSnackbar(route);
  }

  void _showStartSnackbar(TouristRouteEntity route) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${route.name} 코스를 시작합니다!\n걷기가 자동으로 기록됩니다 🏃',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF03C75A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Kakao Mobility 도보 접근 경로 ─────────────────────────────

  Future<List<NLatLng>> _fetchApproachRoute({
    required double fromLat, required double fromLng,
    required double toLat, required double toLng,
  }) async {
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return [];
      final uri = Uri.parse('${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions');
      final res = await http.post(
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
      ).timeout(const Duration(seconds: 10));

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
      debugPrint('[ApproachRoute] $e');
      return [];
    }
  }

  // ── GPX 파싱 ─────────────────────────────────────────────────

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

  Future<void> _fitCamera(
    NaverMapController ctrl,
    List<NLatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(60),
  }) async {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    await ctrl.updateCamera(NCameraUpdate.fitBounds(
      NLatLngBounds(
        southWest: NLatLng(minLat, minLng),
        northEast: NLatLng(maxLat, maxLng),
      ),
      padding: padding,
    ));
  }

  Future<void> _goToCurrentLocation() async {
    if (_ctrl == null) return;
    setState(() => _locating = true);
    try {
      final pos = await fetchMapPosition();
      if (!mounted) return;
      setState(() => _position = pos);
      if (pos != null) {
        await _ctrl!.updateCamera(NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 13,
        ));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _zoomIn() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    await _ctrl!.updateCamera(
        NCameraUpdate.withParams(zoom: (cam.zoom + 1).clamp(1, 21)));
  }

  Future<void> _zoomOut() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    await _ctrl!.updateCamera(
        NCameraUpdate.withParams(zoom: (cam.zoom - 1).clamp(1, 21)));
  }

  @override
  Widget build(BuildContext context) {
    final food = ref.watch(selectedFoodProvider);
    final state = ref.watch(routeSearchProvider);

    ref.listen<RouteSearchState>(routeSearchProvider, (prev, next) {
      // 루트 목록 변경 → 마커 갱신
      if (!next.isLoading && next.routes != prev?.routes) {
        _updateMapMarkers(next.routes, selectedIdx: next.selectedRouteIdx);
      }
      // 선택 루트 변경 → GPX 로드
      if (next.selectedRouteIdx != prev?.selectedRouteIdx &&
          next.routes.isNotEmpty) {
        _onRouteSelected(next.selectedRouteIdx, next.routes);
      }
      // 코스 시작 → 접근 경로 그리기
      if (!( prev?.isStarted ?? false) && next.isStarted) {
        final route = next.selectedRoute;
        if (route != null) _onCourseStarted(route);
      }
    });

    if (food == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // ── 상단 바 ───────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: _kPanel,
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                child: Row(
                  children: [
                    MapControlButton(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: _kWhite87),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kPanelAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(food.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('내 주변 산책로',
                                  style: TextStyle(
                                      fontSize: 10, color: _kWhite45,
                                      fontWeight: FontWeight.w700)),
                              Text('${food.name} · ${food.kcal} kcal',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w800,
                                      color: _kWhite87)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── GPX 로딩 표시 ─────────────────────────────────────────
        if (_gpxLoading)
          Positioned(
            top: _topBarHeight(context) + 12,
            left: 0, right: 0,
            child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
          ),

        // ── 우하단 컨트롤 ─────────────────────────────────────────
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, child) {
            final screenH = MediaQuery.sizeOf(context).height;
            final sheetH = _sheetController.isAttached
                ? _sheetController.size * screenH
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
        ),

        // ── 하단 코스 패널 ────────────────────────────────────────
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.46,
          minChildSize: 0.13,
          maxChildSize: 0.80,
          snap: true,
          snapSizes: const [0.13, 0.46, 0.80],
          builder: (context, scrollController) => _BottomPanel(
            scrollController: scrollController,
            state: state,
            pos: _position,
            isLocating: _locating,
            onSearch: _onSearch,
            onLoadMore: () => ref.read(routeSearchProvider.notifier).loadMore(),
            onTransportChange: (v) {
              final food = ref.read(selectedFoodProvider);
              if (food == null) return;
              ref.read(routeSearchProvider.notifier).setTransport(
                v, food,
                lat: _position?.latitude ?? 37.5635,
                lng: _position?.longitude ?? 126.9869,
              );
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onCardTap: _onRouteCardTap,
          ),
        ),
      ],
    );
  }

  double _topBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;
}

// ── 하단 코스 패널 (CustomScrollView — DraggableScrollableSheet 정상 연동) ──

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.scrollController,
    required this.state,
    required this.pos,
    required this.isLocating,
    required this.onSearch,
    required this.onLoadMore,
    required this.onTransportChange,
    required this.onCardTap,
  });

  final ScrollController scrollController;
  final RouteSearchState state;
  final Position? pos;
  final bool isLocating;
  final VoidCallback onSearch;
  final VoidCallback onLoadMore;
  final void Function(String) onTransportChange;
  final void Function(int, TouristRouteEntity) onCardTap;

  @override
  Widget build(BuildContext context) {
    final hasRoutes = state.routes.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: _kPanel,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // ── 핸들 + 이동수단 토글 ────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40, height: 4,
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

            // ── 콘텐츠 ──────────────────────────────────────────
            if (isLocating)
              const SliverFillRemaining(
                child: Center(
                  child: Text('위치를 확인하는 중...',
                      style: TextStyle(
                          color: _kWhite45, fontSize: 14,
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
                      const Icon(Icons.map_outlined, size: 36, color: _kWhite45),
                      const SizedBox(height: 12),
                      const Text('현재 위치 주변 코스를 찾아보세요',
                          style: TextStyle(
                              color: _kWhite45, fontSize: 13,
                              fontWeight: FontWeight.w600)),
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
                                      fontSize: 14, fontWeight: FontWeight.w800,
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
                        style: const TextStyle(fontSize: 11, color: _kWhite45),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RouteCard(
                      route: state.routes[i],
                      transport: state.transport,
                      isSelected: i == state.selectedRouteIdx,
                      onTap: () => onCardTap(i, state.routes[i]),
                    ),
                    childCount: state.routes.length,
                  ),
                ),
              ),
              // ── 더 보기 버튼 ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      12, 4, 12, context.bottomPadding + 12),
                  child: state.isLoadingMore
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                                color: Color(0xFF03C75A), strokeWidth: 2),
                          ),
                        )
                      : state.hasMore
                          ? GestureDetector(
                              onTap: onLoadMore,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _kPanelAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.expand_more_rounded,
                                        size: 18, color: _kWhite45),
                                    const SizedBox(width: 6),
                                    Text(
                                      '코스 더 보기 (${state.allRoutes.length - state.displayedRoutes.length}개 남음)',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _kWhite45),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(height: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 이동수단 토글 ─────────────────────────────────────────────────────────────

class _TransportToggle extends StatelessWidget {
  const _TransportToggle({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
          color: _kPanelAlt, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
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
      ]),
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
              Icon(icon, size: 15, color: selected ? _kWhite87 : _kWhite45),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: selected ? _kWhite87 : _kWhite45)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 코스 카드 ────────────────────────────────────────────────────────────────

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
            Row(children: [
              Icon(
                transport == 'walk'
                    ? Icons.hiking_rounded
                    : Icons.directions_bike_rounded,
                size: 15,
                color: isSelected ? const Color(0xFF03C75A) : _kWhite45,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(route.name,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF03C75A) : _kWhite87,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
              if (route.isLocal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF03C75A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('내 지역',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF03C75A),
                          fontWeight: FontWeight.w700)),
                ),
              ] else if (route.region != null) ...[
                const SizedBox(width: 6),
                Text(route.region!,
                    style: const TextStyle(
                        fontSize: 11, color: _kWhite45,
                        fontWeight: FontWeight.w600)),
              ],
              if (route.gpxpath != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.route_rounded, size: 13, color: _kWhite45),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _kWhite45),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (route.distanceFromUserM != null) ...[
                _InfoChip(
                  icon: Icons.near_me_rounded,
                  label: route.distanceFromUserM! < 1000
                      ? '${route.distanceFromUserM}m'
                      : '${(route.distanceFromUserM! / 1000).toStringAsFixed(1)}km',
                  color: const Color(0xFF03C75A),
                ),
                const SizedBox(width: 8),
              ],
              if (route.hasDetailInfo) ...[
                _InfoChip(
                    icon: Icons.straighten_rounded,
                    label: '${route.distanceKm.toStringAsFixed(1)}km'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: '${route.durationMinutes}분'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '~${route.kcal}kcal'),
              ] else ...[
                const _InfoChip(
                    icon: Icons.info_outline_rounded, label: '상세정보 없음'),
              ],
              if (route.tags.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(route.tags.first,
                    style: const TextStyle(fontSize: 11, color: _kWhite45)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kWhite45;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ],
    );
  }
}
