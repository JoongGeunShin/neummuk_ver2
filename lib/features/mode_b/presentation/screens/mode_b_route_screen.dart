import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/calorie_compare_donut.dart';
import '../../../../core/widgets/map_canvas.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../providers/mode_b_provider.dart';

class ModeBRouteScreen extends ConsumerWidget {
  const ModeBRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final food = ref.watch(selectedFoodProvider);
    final state = ref.watch(routeSearchProvider);
    final notifier = ref.read(routeSearchProvider.notifier);

    if (food == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/mode-b'));
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Map
          MapCanvas(
            route: RouteData(
              points: const [
                Offset(140, 290), Offset(200, 380), Offset(310, 540),
                Offset(420, 660), Offset(560, 790), Offset(620, 870),
              ],
              color: c.secondary,
            ),
            markers: const [
              MapMarkerData(x: 200, y: 360, kind: MarkerKind.sight),
              MapMarkerData(x: 460, y: 660, kind: MarkerKind.sight),
              MapMarkerData(x: 620, y: 870, kind: MarkerKind.sight),
            ],
            userPosition: const Offset(140, 290),
            translateX: -40,
            translateY: -100,
            scale: 1.05,
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/mode-b'),
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text(food.emoji, style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('먹기 위한 활동',
                                      style: TextStyle(fontSize: 11, color: Colors.white70,
                                          fontWeight: FontWeight.w700)),
                                  Text('${food.name} · ${food.kcal} kcal',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
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

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              constraints: BoxConstraints(maxHeight: context.screenHeight * 0.78),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, -12))],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: c.textFaint.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(context.wp(5), 4, context.wp(5), 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Donut + stats
                          Row(
                            children: [
                              CalorieCompareDonut(
                                kcalBurn: (food.kcal * 0.85).round(),
                                kcalFood: food.kcal,
                                size: 140,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('이 음식을 위해 필요한',
                                        style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${state.transport == 'walk' ? '🚶' : '🚲'} ${food.minutesFor(state.transport)}분',
                                      style: TextStyle(
                                          fontSize: context.wp(7),
                                          fontWeight: FontWeight.w800, color: c.text,
                                          letterSpacing: -0.8, height: 1.1),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '약 ${(food.minutesFor(state.transport) * (state.transport == 'walk' ? 0.075 : 0.28)).toStringAsFixed(1)} km · ${(food.kcal * 0.85).round()} kcal 소모',
                                      style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: c.primarySoft,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome_rounded, size: 12, color: c.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${((food.kcal * 0.85) / food.kcal * 100).round()}% 상쇄',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.hp(2)),
                          // Activity toggle
                          SegmentedControl(
                            value: state.transport,
                            options: const [
                              SegmentOption(value: 'walk', label: '걷기', icon: Icons.directions_walk_rounded),
                              SegmentOption(value: 'bike', label: '자전거', icon: Icons.directions_bike_rounded),
                            ],
                            onChanged: (v) => notifier.setTransport(v, food),
                          ),
                          SizedBox(height: context.hp(2.2)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('이 칼로리에 맞는 코스 ${state.routes.length}개',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                      color: c.text, letterSpacing: -0.2)),
                              Text('관광공사 데이터',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)),
                            ],
                          ),
                          SizedBox(height: context.hp(1)),
                          // Route list
                          if (state.isLoading)
                            Center(child: Padding(
                              padding: EdgeInsets.all(context.hp(3)),
                              child: CircularProgressIndicator(color: c.primary),
                            ))
                          else
                            ...state.routes.asMap().entries.map((entry) {
                              final i = entry.key;
                              final r = entry.value;
                              final on = i == state.selectedRouteIdx;
                              return GestureDetector(
                                onTap: () => notifier.selectRoute(i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: EdgeInsets.only(bottom: context.hp(1.2)),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: on ? c.primarySoft : c.surfaceAlt,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: on ? c.primary : c.outline,
                                        width: on ? 2 : 1),
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(
                                          color: on ? c.primary : c.surfaceHi,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          state.transport == 'walk'
                                              ? Icons.hiking_rounded
                                              : Icons.directions_bike_rounded,
                                          size: 22,
                                          color: on ? Colors.white : c.text,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.name,
                                                style: TextStyle(
                                                    color: on ? c.primary : c.text,
                                                    fontWeight: FontWeight.w800, fontSize: 14),
                                                overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text('${r.distanceKm}km · ${r.durationMinutes}분 · ${r.kcal}kcal',
                                                style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 4,
                                              children: r.tags.map((tag) => Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: on
                                                      ? Colors.white.withValues(alpha: 0.15)
                                                      : c.surfaceHi,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Text(tag,
                                                    style: TextStyle(
                                                        fontSize: 10, fontWeight: FontWeight.w700,
                                                        color: on ? c.primary : c.textMuted)),
                                              )).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                        color: on ? c.primary : c.textFaint,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          SizedBox(height: context.hp(1.5)),
                          AppButton(
                            label: '이 코스로 시작하기',
                            onPressed: () => context.go('/record'),
                            variant: ButtonVariant.primary,
                            icon: Icons.navigation_rounded,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),        // Column
              ),        // SafeArea
            ),          // Container
          ),            // Positioned
        ],
      ),
    );
  }
}
