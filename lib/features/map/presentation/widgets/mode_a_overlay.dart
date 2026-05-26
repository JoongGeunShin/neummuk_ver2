import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../../core/widgets/tiny_ring.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../../mode_a/domain/entities/route_result_entity.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../walk/presentation/providers/walk_provider.dart';

class ModeAOverlay extends ConsumerStatefulWidget {
  const ModeAOverlay({
    super.key,
    required this.controller,
    required this.events,
  });

  final NaverMapController? controller;
  final MapEventSink events;

  @override
  ConsumerState<ModeAOverlay> createState() => _ModeAOverlayState();
}

class _ModeAOverlayState extends ConsumerState<ModeAOverlay> {
  bool _locating = false;
  bool _sheetExpanded = false;
  final _toCtrl = TextEditingController();

  NaverMapController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toCtrl.text = ref.read(modeAProvider).to;
    });
    widget.events.onLongTapped = _onLongPress;
  }

  @override
  void didUpdateWidget(covariant ModeAOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller == null && widget.controller != null) {
      _fetchGpsOrigin();
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsOrigin() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      final pos = await fetchMapPosition();
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

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await fetchMapPosition();
      if (!mounted || pos == null) return;
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

  void _onLongPress(NPoint point, NLatLng latLng) {
    final state = ref.read(modeAProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LongPressSheet(
        latLng: latLng,
        canAddWaypoint: state.waypoints.length < 3,
        onSetOrigin: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setOriginGps(
                latLng.latitude, latLng.longitude, '선택한 위치');
          setState(() {});
        },
        onSetDest: () {
          Navigator.pop(context);
          ref.read(modeAProvider.notifier).setDestCoords(
                latLng.latitude, latLng.longitude, '선택한 위치');
          _toCtrl.text = '선택한 위치';
        },
        onAddWaypoint: () {
          Navigator.pop(context);
          final wpIdx = ref.read(modeAProvider).waypoints.length + 1;
          ref.read(modeAProvider.notifier).addWaypoint(RouteWaypoint(
                name: '경유지 $wpIdx',
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              ));
        },
      ),
    );
  }

  Future<void> _onSearch() async {
    FocusScope.of(context).unfocus();
    await ref.read(modeAProvider.notifier).search();
    if (mounted && ref.read(modeAProvider).routeResult != null) {
      setState(() => _sheetExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final state = ref.watch(modeAProvider);

    ref.listen<ModeAState>(modeAProvider, (prev, next) {
      if (prev?.to != next.to && _toCtrl.text != next.to) {
        _toCtrl.text = next.to;
      }
    });

    return Stack(
      children: [
        // ── 상단 경로 입력 패널 ──────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: _RoutePanel(
            state: state,
            locating: _locating,
            toCtrl: _toCtrl,
            onToChanged: (v) => ref.read(modeAProvider.notifier).setTo(v),
            onSetTransport: (t) =>
                ref.read(modeAProvider.notifier).setTransport(t),
            onRemoveWaypoint: (i) =>
                ref.read(modeAProvider.notifier).removeWaypoint(i),
            onWaypointHint: () =>
                ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('지도를 길게 눌러 경유지를 추가하세요'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            onSearch: state.to.isEmpty ? null : _onSearch,
            onBack: () => context.pop(),
          ),
        ),

        // ── 우하단 줌 + 위치 버튼 ────────────────────────────────
        Positioned(
          right: 12,
          bottom: (state.routeResult != null
                  ? context.screenHeight *
                      (_sheetExpanded ? 0.82 : 0.52)
                  : 0) +
              bottomPad +
              16,
          child: MapZoomControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onLocation: _goToCurrentLocation,
            isLocating: _locating,
          ),
        ),

        // ── 칼로리 위젯 (우상단, 패널 아래) ──────────────────────
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 220,
          child: _KcalWidget(routeKcal: state.routeResult?.kcalBurn),
        ),

        // ── 경로 결과 하단 시트 ──────────────────────────────────
        if (state.routeResult != null)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: _sheetExpanded
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
              child: _ResultSheet(
                state: state,
                expanded: _sheetExpanded,
                onToggleExpand: () =>
                    setState(() => _sheetExpanded = !_sheetExpanded),
                onRestaurantTap: (id) => context.push('/restaurant/$id'),
              ),
            ),
          ),

        // ── 로딩 오버레이 ────────────────────────────────────────
        if (state.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(
                    color: kMapGreen, strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── 경로 입력 패널 ──────────────────────────────────────────────────────────

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.state,
    required this.locating,
    required this.toCtrl,
    required this.onToChanged,
    required this.onSetTransport,
    required this.onRemoveWaypoint,
    required this.onWaypointHint,
    required this.onSearch,
    required this.onBack,
  });

  final ModeAState state;
  final bool locating;
  final TextEditingController toCtrl;
  final ValueChanged<String> onToChanged;
  final ValueChanged<String> onSetTransport;
  final ValueChanged<int> onRemoveWaypoint;
  final VoidCallback onWaypointHint;
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _FieldRow(
                    dot: const _Dot(isGps: true),
                    child: locating
                        ? const Row(children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kMapWhite45)),
                            SizedBox(width: 8),
                            Text('위치 확인 중...',
                                style: TextStyle(
                                    color: kMapWhite45,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ])
                        : Text(
                            state.from.isEmpty ? '출발지를 설정해주세요' : state.from,
                            style: TextStyle(
                              color: state.from.isEmpty
                                  ? kMapWhite45
                                  : kMapWhite87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 16),
                  _FieldRow(
                    dot: const _Dot(isPin: true),
                    child: TextField(
                      controller: toCtrl,
                      onChanged: onToChanged,
                      style: const TextStyle(
                          color: kMapWhite87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '어디로 갈까요?',
                        hintStyle: const TextStyle(
                            color: kMapWhite45, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        suffixIcon: toCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  toCtrl.clear();
                                  onToChanged('');
                                },
                                child: const Icon(Icons.cancel_rounded,
                                    size: 16, color: kMapWhite45),
                              )
                            : null,
                      ),
                    ),
                  ),
                  ...state.waypoints.asMap().entries.map((e) => Column(
                        children: [
                          const Divider(
                              color: Colors.white12, height: 1, indent: 16),
                          _FieldRow(
                            dot: const _Dot(isWaypoint: true),
                            child: Row(children: [
                              Expanded(
                                child: Text(e.value.name,
                                    style: const TextStyle(
                                        color: kMapWhite87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              GestureDetector(
                                onTap: () => onRemoveWaypoint(e.key),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: kMapWhite45),
                              ),
                            ]),
                          ),
                        ],
                      )),
                ],
              ),
            ),
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
                  if (state.waypoints.length < 3)
                    GestureDetector(
                      onTap: onWaypointHint,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.add_location_alt_outlined,
                            size: 20, color: kMapWhite45),
                      ),
                    ),
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
                      child: Text(
                        '검색',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onSearch != null ? Colors.white : kMapWhite45,
                        ),
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

// ─── 결과 하단 시트 ──────────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.state,
    required this.expanded,
    required this.onToggleExpand,
    required this.onRestaurantTap,
  });

  final ModeAState state;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onRestaurantTap;

  @override
  Widget build(BuildContext context) {
    final result = state.routeResult!;

    return Column(
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kMapHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
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
    );
  }
}

// ─── 음식점 카드 ─────────────────────────────────────────────────────────────

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

// ─── 롱프레스 위치 설정 시트 ─────────────────────────────────────────────────

class _LongPressSheet extends StatelessWidget {
  const _LongPressSheet({
    required this.latLng,
    required this.canAddWaypoint,
    required this.onSetOrigin,
    required this.onSetDest,
    required this.onAddWaypoint,
  });

  final NLatLng latLng;
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
            '${latLng.latitude.toStringAsFixed(5)}, '
            '${latLng.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
                color: kMapWhite45, fontSize: 12, fontWeight: FontWeight.w500),
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
              _SheetBtn(
                  label: '출발지',
                  icon: Icons.trip_origin_rounded,
                  color: const Color(0xFF7C8AFF),
                  onTap: onSetOrigin),
              const SizedBox(width: 8),
              _SheetBtn(
                  label: '도착지',
                  icon: Icons.place_rounded,
                  color: const Color(0xFFFF4D6D),
                  onTap: onSetDest),
              if (canAddWaypoint) ...[
                const SizedBox(width: 8),
                _SheetBtn(
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

// ─── 칼로리 위젯 ─────────────────────────────────────────────────────────────

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

// ─── 소형 공용 위젯들 ──────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.dot, required this.child});
  final Widget dot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: dot)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.isGps = false, this.isPin = false, this.isWaypoint = false});
  final bool isGps;
  final bool isPin;
  final bool isWaypoint;

  @override
  Widget build(BuildContext context) {
    if (isPin) {
      return const Icon(Icons.place_rounded,
          size: 14, color: Color(0xFFFF4D6D));
    }
    if (isWaypoint) {
      return const Icon(Icons.add_location_alt_rounded,
          size: 14, color: Color(0xFFFFC56E));
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF7C8AFF),
        border: Border.all(color: Colors.white54, width: 1.5),
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  const _SheetBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kMapWhite87)),
            ],
          ),
        ),
      ),
    );
  }
}
