import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_ext.dart';
import '../../domain/entities/food_catalog_entity.dart';
import 'food_card.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

class PopularSection extends ConsumerWidget {
  const PopularSection({super.key, required this.foods});

  final List<FoodCatalogEntity> foods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.primary, c.secondary],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '🔥',
                        style: AppTypography.headline.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '지금 많이 찾는 메뉴',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '사람들이 자주 검색한 음식이에요',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '인기 메뉴',
              style: AppTypography.h3.copyWith(
                color: c.text,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),

        if (foods.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  '로딩 중...',
                  style: AppTypography.bodyMute.copyWith(
                    fontWeight: FontWeight.w400,
                    color: c.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              context.hp(3) + context.bottomPadding,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: context.screenWidth * 0.44 / 200,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => FoodCard(food: foods[i], showRank: i < 3),
                childCount: foods.length,
              ),
            ),
          ),
      ],
    );
  }
}
