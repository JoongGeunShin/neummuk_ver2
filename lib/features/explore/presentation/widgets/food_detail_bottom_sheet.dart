import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../features/mode_b/domain/entities/food_entity.dart';
import '../../../../features/mode_b/presentation/providers/mode_b_provider.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../providers/explore_provider.dart';

/// 음식 상세 영양성분 바텀시트.
/// 핸들 → 음식 헤더 → 열량 강조 → 6대 영양소 → Mode B 연결 버튼
class FoodDetailBottomSheet extends ConsumerWidget {
  const FoodDetailBottomSheet({super.key, required this.food});

  final FoodCatalogEntity food;

  static Future<void> show(
      BuildContext context, WidgetRef ref, FoodCatalogEntity food) {
    ref.read(exploreProvider.notifier).onFoodTapped(food);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailBottomSheet(food: food),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final n = food.nutrition;
    final walkMin = _walkMinutes(n.caloriesKcal);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, context.bottomPadding + 20),
          children: [
            // 핸들
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.outline,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            // 음식 헤더
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      food.emoji,
                      style: TextStyle(fontSize: context.wp(9)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.displayName,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              food.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '1인분 기준 ${n.servingSizeG.toStringAsFixed(0)}g',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 열량 강조 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.primary.withValues(alpha: 0.15),
                    c.secondary.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: c.primary, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('총 열량',
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 28),
                          children: [
                            TextSpan(
                                text: n.caloriesKcal.toStringAsFixed(0)),
                            TextSpan(
                              text: ' kcal',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: c.textMuted,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('걸어서 소모',
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Icon(Icons.directions_walk_rounded,
                              size: 16, color: c.secondary),
                          const SizedBox(width: 4),
                          Text(
                            '$walkMin분',
                            style: TextStyle(
                                color: c.secondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 6대 영양소
            Text('영양성분',
                style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: [
                _NutrientTile(
                    label: '탄수화물',
                    value: '${n.carbsG.toStringAsFixed(1)}g'),
                _NutrientTile(
                    label: '당류',
                    value: '${n.sugarG.toStringAsFixed(1)}g'),
                _NutrientTile(
                    label: '단백질',
                    value: '${n.proteinG.toStringAsFixed(1)}g'),
                _NutrientTile(
                    label: '지방',
                    value: '${n.fatG.toStringAsFixed(1)}g'),
                _NutrientTile(
                    label: '나트륨',
                    value: '${n.sodiumMg.toStringAsFixed(0)}mg'),
                if (n.saturatedFatG != null)
                  _NutrientTile(
                      label: '포화지방',
                      value: '${n.saturatedFatG!.toStringAsFixed(1)}g')
                else
                  _NutrientTile(
                      label: '콜레스테롤',
                      value: n.cholesterolMg != null
                          ? '${n.cholesterolMg!.toStringAsFixed(0)}mg'
                          : '-'),
              ],
            ),

            const SizedBox(height: 24),

            // Mode B 연결
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                final fe = FoodEntity(
                  id: food.canonicalName,
                  name: food.displayName,
                  kcal: n.caloriesKcal.round(),
                  category: food.category,
                  emoji: food.emoji,
                  walkMinutes: walkMin,
                  bikeMinutes: _bikeMinutes(n.caloriesKcal),
                );
                ref.read(selectedFoodProvider.notifier).set(fe);
                ref.read(routeSearchProvider.notifier).loadRoutes(fe);
                context.go('/mode-b/route');
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.primary, c.secondary]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: c.primaryGlow,
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '이 음식 소모하는 루트 찾기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _walkMinutes(double kcal) {
    final hours = kcal / (AppConstants.metValues['walk']! * 65.0);
    return (hours * 60).round().clamp(1, 999);
  }

  int _bikeMinutes(double kcal) {
    final hours = kcal / (AppConstants.metValues['bike']! * 65.0);
    return (hours * 60).round().clamp(1, 999);
  }
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outline),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
        ],
      ),
    );
  }
}
