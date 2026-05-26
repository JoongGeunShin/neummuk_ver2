import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../providers/explore_provider.dart';
import '../widgets/food_detail_bottom_sheet.dart';

const _categories = [
  '전체',
  '치킨',
  '족발·보쌈',
  '돈까스·회·일식',
  '피자',
  '구이·고기',
  '야식',
  '양식',
  '중식',
  '아시안',
  '백반·죽·국수',
  '도시락',
  '분식',
  '카페·디저트',
  '패스트푸드',
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(exploreProvider);
    final notifier = ref.read(exploreProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // ── 헤더 ─────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뒤로가기 + 타이틀 (내 기록·MY 페이지와 동일 패턴)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.wp(2), context.hp(1), context.wp(3), 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: c.text, size: 20),
                      ),
                      Text(
                        '탐색',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // 검색바 + 카테고리 칩
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: c.textMuted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: notifier.setQuery,
                                style: TextStyle(
                                    color: c.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '음식 이름으로 검색 (예: 삼겹살, 타코야끼)',
                                  hintStyle: TextStyle(
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (state.query.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  notifier.setQuery('');
                                },
                                child: Icon(Icons.close_rounded,
                                    color: c.textMuted, size: 18),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (ctx, i) => AppChip(
                            label: _categories[i],
                            active: state.category == _categories[i],
                            onTap: () =>
                                notifier.setCategory(_categories[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 콘텐츠 ───────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: c.primary))
                : state.isSearchMode
                    ? _SearchResults(
                        foods: state.results,
                        query: state.query,
                      )
                    : _PopularSection(foods: state.popularFoods),
          ),
        ],
      ),
    );
  }
}

// ── 검색 결과 ──────────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.foods, required this.query});

  final List<FoodCatalogEntity> foods;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: context.wp(14))),
            const SizedBox(height: 12),
            Text('"$query" 검색 결과가 없어요',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('다른 이름으로 검색해보세요',
                style: TextStyle(
                    color: c.textFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('${foods.length}개 결과',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.textMuted,
                  letterSpacing: 0.4)),
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
            itemBuilder: (ctx, i) => _FoodCard(food: foods[i]),
          ),
        ),
      ],
    );
  }
}

// ── 인기 섹션 ──────────────────────────────────────────────────────────────────

class _PopularSection extends ConsumerWidget {
  const _PopularSection({required this.foods});

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
                    child: const Center(
                        child:
                            Text('🔥', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('지금 많이 찾는 메뉴',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1)),
                        SizedBox(height: 2),
                        Text('사람들이 자주 검색한 음식이에요',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  const Icon(Icons.trending_up_rounded,
                      size: 22, color: Colors.white),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('인기 메뉴',
                style: TextStyle(
                    color: c.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2)),
          ),
        ),

        if (foods.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('로딩 중...',
                    style: TextStyle(color: c.textMuted, fontSize: 14)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, context.hp(3) + context.bottomPadding),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: context.screenWidth * 0.44 / 200,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) =>
                    _FoodCard(food: foods[i], showRank: i < 3),
                childCount: foods.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 공통 음식 카드 ─────────────────────────────────────────────────────────────

class _FoodCard extends ConsumerWidget {
  const _FoodCard({required this.food, this.showRank = false});

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
          ref.read(routeSearchProvider.notifier).loadRoutes(selected);
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
                          text: food.nutrition.caloriesKcal
                              .toStringAsFixed(0)),
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
                      Icon(Icons.search_rounded,
                          size: 10, color: c.textFaint),
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
