import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../mode_b/domain/entities/food_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';

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
        _ctrl!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(pos.latitude, pos.longitude),
            zoom: 13,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pos = await fetchMapPosition();
    if (!mounted) return;
    setState(() {
      _position = pos;
      _locating = false;
    });
    if (pos != null && _ctrl != null) {
      await _ctrl!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 13,
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_ctrl == null) return;
    setState(() => _locating = true);
    try {
      final pos = await fetchMapPosition();
      if (!mounted) return;
      setState(() => _position = pos);
      if (pos != null) {
        await _ctrl!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(pos.latitude, pos.longitude),
            zoom: 13,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _zoomIn() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    await _ctrl!
        .updateCamera(NCameraUpdate.withParams(zoom: (cam.zoom + 1).clamp(1, 21)));
  }

  Future<void> _zoomOut() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    await _ctrl!
        .updateCamera(NCameraUpdate.withParams(zoom: (cam.zoom - 1).clamp(1, 21)));
  }

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

  Future<void> _updateMapMarkers(List<TouristRouteEntity> routes) async {
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

  Future<void> _selectRoute(int idx) async {
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
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    await ctrl.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = ref.watch(selectedFoodProvider);
    final state = ref.watch(routeSearchProvider);
    final pos = _position;

    ref.listen<RouteSearchState>(routeSearchProvider, (prev, next) {
      if (!next.isLoading && next.routes != prev?.routes) {
        _updateMapMarkers(next.routes);
      }
    });

    if (food == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // ── 상단 바 ────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
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
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: _kWhite87),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
          ),
        ),

        // ── GPX 로딩 표시 ──────────────────────────────────────────
        if (_gpxLoading)
          Positioned(
            top: _topBarHeight(context) + 12,
            left: 0, right: 0,
            child: const Center(child: MapLoadingChip('경로 불러오는 중...')),
          ),

        // ── 우하단 컨트롤 ──────────────────────────────────────────
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

        // ── 하단 코스 패널 (드래그 가능) ────────────────────────────
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
            food: food,
            pos: pos,
            isLocating: _locating,
            onSearch: _onSearch,
            onTransportChange: (v) {
              final notifier = ref.read(routeSearchProvider.notifier);
              notifier.setTransport(
                v, food,
                lat: pos?.latitude ?? 37.5635,
                lng: pos?.longitude ?? 126.9869,
              );
              _ctrl?.clearOverlays(type: NOverlayType.polylineOverlay);
            },
            onSelectRoute: _selectRoute,
            onStartTap: () => context.go('/record'),
          ),
        ),
      ],
    );
  }

  double _topBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 66;
}

// ── 하단 코스 패널 ───────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
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
                    label: '${route.distanceKm.toStringAsFixed(1)}km',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: '${route.durationMinutes}분',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '~${route.kcal}kcal',
                  ),
                ] else ...[
                  const _InfoChip(
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
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ],
    );
  }
}

// ── 이미지 갤러리 ─────────────────────────────────────────────────────────────

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
