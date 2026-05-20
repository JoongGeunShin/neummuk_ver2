import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/map_canvas.dart';
import '../../../../core/widgets/tiny_ring.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../providers/mode_a_provider.dart';

class ModeAMainScreen extends ConsumerStatefulWidget {
  const ModeAMainScreen({super.key});

  @override
  ConsumerState<ModeAMainScreen> createState() => _ModeAMainScreenState();
}

class _ModeAMainScreenState extends ConsumerState<ModeAMainScreen> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Trigger initial search with default values if result not yet loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = ref.read(modeAProvider);
      if (st.routeResult == null && !st.isLoading) {
        ref.read(modeAProvider.notifier).search();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(modeAProvider);
    final result = state.routeResult;

    final transports = [
      ('walk', '도보', Icons.directions_walk_rounded),
      ('bike', '자전거', Icons.directions_bike_rounded),
      ('transit', '대중교통', Icons.directions_bus_rounded),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Map background
          MapCanvas(
            route: RouteData(
              points: const [
                Offset(140, 290), Offset(200, 380), Offset(260, 470),
                Offset(310, 540), Offset(360, 580), Offset(420, 660),
                Offset(500, 720), Offset(560, 790), Offset(620, 870),
              ],
              color: c.primary,
            ),
            markers: state.restaurants.take(4).map((r) => MapMarkerData(
              x: (r.longitude - 126.9860) * 10000 + 400,
              y: (37.5645 - r.latitude) * 10000 + 500,
              kind: r.kind == 'cafe' ? MarkerKind.cafe : MarkerKind.food,
            )).toList(),
            userPosition: const Offset(140, 290),
            translateX: -40,
            translateY: -120,
            scale: 1.05,
          ),

          // Top floating header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/mode-a'),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.pinUser,
                                        border: const Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    result?.fromName ?? '광화문역 5번 출구',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                        color: Colors.white, height: 1),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.place_rounded, size: 12, color: c.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    result?.toName ?? '남산서울타워',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right action buttons
          Positioned(
            right: 12,
            top: 90,
            child: Column(
              children: [
                _MapBtn(icon: Icons.my_location_rounded),
                const SizedBox(height: 10),
                _MapBtn(icon: Icons.layers_rounded),
              ],
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: _expanded
                  ? context.screenHeight * 0.85
                  : context.screenHeight * 0.58,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, -12))],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                children: [
                  // Drag handle
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: c.textFaint.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.wp(5)),
                    child: Column(
                      children: [
                        // Transport tabs
                        Row(
                          children: transports.map((t) {
                            final (id, label, icon) = t;
                            final on = state.transport == id;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => ref.read(modeAProvider.notifier).setTransport(id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 56,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: on ? c.primary : c.surfaceAlt,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(icon, size: 20,
                                          color: on ? c.onPrimary : c.textMuted),
                                      const SizedBox(height: 2),
                                      Text(label,
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w700,
                                              color: on ? c.onPrimary : c.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Big stats
                        SizedBox(height: context.hp(2.5)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('예상 소모',
                                    style: TextStyle(fontSize: 11, color: c.textMuted,
                                        fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      state.isLoading ? '...' : '${result?.kcalBurn ?? 235}',
                                      style: TextStyle(
                                          fontSize: context.wp(10.5),
                                          fontWeight: FontWeight.w800, color: c.primary,
                                          letterSpacing: -1.5, height: 1),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('kcal',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${result?.distanceKm ?? 3.2} km · ${result?.durationMinutes ?? 42}분',
                                  style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.local_fire_department_rounded,
                                        size: 16, color: c.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      state.transport == 'walk'
                                          ? '도보 추천'
                                          : state.transport == 'bike'
                                              ? '자전거 추천'
                                              : '대중교통',
                                      style: TextStyle(fontSize: 13, color: c.text, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Progress bar
                        SizedBox(height: context.hp(2)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(height: 8, color: c.surfaceHi),
                              FractionallySizedBox(
                                widthFactor: 0.45,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [c.primary, c.secondary]),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Restaurants
                  Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(2.2), context.wp(5), 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('도착지 근처 추천 맛집',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                            const SizedBox(height: 2),
                            Text('소모 칼로리 ±20% 범위에서 추천',
                                style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('전체', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary)),
                              Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: state.isLoading
                        ? Center(child: CircularProgressIndicator(color: c.primary))
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(context.wp(5), 4, context.wp(5), 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: state.restaurants.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: context.wp(58),
                                child: _RestaurantCard(
                                  restaurant: state.restaurants[i],
                                  kcalBurn: result?.kcalBurn ?? 235,
                                  onTap: () => context.go('/restaurant/${state.restaurants[i].id}'),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),        // Column
              ),        // SafeArea
            ),          // AnimatedContainer
          ),            // Positioned
        ],
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outline),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, size: 22, color: c.text),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.kcalBurn,
    required this.onTap,
  });
  final RestaurantEntity restaurant;
  final int kcalBurn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = restaurant;
    final ratio = r.kcal / kcalBurn;
    final matchPct = (100 - (1 - ratio).abs() * 100).clamp(0.0, 100.0);
    final matchColor = ratio < 1.1 && ratio > 0.9
        ? c.success
        : ratio < 1.4 ? c.kcalActivity : c.warn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.outline),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImageWidget(
              type: FoodImageWidget.fromString(r.imageType),
              height: 108,
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
                            style: TextStyle(color: c.text, fontWeight: FontWeight.w800,
                                fontSize: 14, letterSpacing: -0.1),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      TinyRing(pct: matchPct, size: 30, color: matchColor,
                          label: '${matchPct.round()}'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${r.menu} · ${r.kcal} kcal',
                      style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: c.accent),
                      const SizedBox(width: 3),
                      Text(r.rating.toString(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text)),
                      Text(' · ${r.distanceLabel} · ${r.walkLabel}',
                          style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
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
