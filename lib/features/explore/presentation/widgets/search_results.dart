import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_ext.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../providers/explore_provider.dart';
import 'food_card.dart';

class SearchResults extends ConsumerWidget {
  const SearchResults({
    super.key,
    required this.foods,
    required this.query,
    required this.onAddNew,
  });

  final List<FoodCatalogEntity> foods;
  final String query;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isLoading =
        ref.watch(exploreProvider.select((s) => s.isLoadingCandidates));

    if (foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🙁', style: TextStyle(fontSize: context.wp(14))),
            const SizedBox(height: 12),
            Text('"$query" 검색 결과가 없어요',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('음식 정보를 찾아보고 추가해볼까요?',
                style: TextStyle(
                    color: c.textFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: isLoading ? null : onAddNew,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isLoading
                      ? c.primary.withValues(alpha: 0.6)
                      : c.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isLoading
                      ? [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Text('찾아보는 중...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ]
                      : const [
                          Icon(Icons.add_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('새로 추가하기',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('${foods.length}개 결과',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.textMuted,
                      letterSpacing: 0.4)),
              const Spacer(),
              GestureDetector(
                onTap: isLoading ? null : onAddNew,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isLoading
                      ? [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: c.primary),
                          ),
                          const SizedBox(width: 4),
                          Text('찾아보는 중...',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary)),
                        ]
                      : [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: c.primary),
                          const SizedBox(width: 4),
                          Text('새로 추가',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary)),
                        ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, context.hp(3) + context.bottomPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: context.screenWidth * 0.44 / 200,
            ),
            itemCount: foods.length,
            itemBuilder: (ctx, i) => FoodCard(food: foods[i]),
          ),
        ),
      ],
    );
  }
}
