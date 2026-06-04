import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../../domain/entities/food_catalog_entity.dart';
import 'food_detail_bottom_sheet.dart';

class FoodCard extends ConsumerWidget {
  const FoodCard({super.key, required this.food, this.showRank = false});

  final FoodCatalogEntity food;
  final bool showRank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return GestureDetector(
      onTap: () async {
        final selected = await FoodDetailBottomSheet.show(context, ref, food);
        if (selected != null && context.mounted) {
          ref.read(selectedFoodProvider.notifier).set(selected);
          ref.read(routeSearchProvider.notifier).reset();
          ref.read(mapModeProvider.notifier).set(MapMode.modeB);
          context.push('/map');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(food.emoji,
                        style: TextStyle(fontSize: context.wp(7))),
                  ),
                ),
                if (showRank)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🔥', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              food.displayName,
              style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.1),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              food.category,
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                    children: [
                      TextSpan(
                          text: food.nutrition.caloriesKcal.toStringAsFixed(0)),
                      TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                              fontSize: 10,
                              color: c.textMuted,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (food.searchCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, size: 10, color: c.textFaint),
                      const SizedBox(width: 2),
                      Text(
                        '${food.searchCount}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: c.textFaint),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
