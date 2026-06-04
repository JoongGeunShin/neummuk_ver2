import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../providers/explore_provider.dart';
import '../widgets/food_detail_bottom_sheet.dart';

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

    // 카테고리가 로드되면 동적으로 사용, 그 전에는 빈 목록 유지
    final categories = state.categories.isEmpty
        ? const ['전체']
        : state.categories;

    return DoubleBackToExit(
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            // ── 헤더 ─────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => notifier.submitSearch(),
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
                              if (state.query.isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    notifier.setQuery('');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: c.textMuted, size: 18),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: notifier.submitSearch,
                                  child: state.isSearchingApi
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: c.primary,
                                          ),
                                        )
                                      : Icon(Icons.search_rounded,
                                          color: c.primary, size: 20),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, i) => AppChip(
                              label: categories[i],
                              active: state.category == categories[i],
                              onTap: () =>
                                  notifier.setCategory(categories[i]),
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
              child: AbsorbPointer(
                absorbing: state.isLoadingCandidates,
                child: state.isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: c.primary))
                    : state.isSearchMode
                        ? _SearchResults(
                            foods: state.results,
                            query: state.query,
                            onAddNew: () =>
                                _showAddFoodDialog(context, ref, state.query),
                          )
                        : _PopularSection(foods: state.popularFoods),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddFoodDialog(
    BuildContext context,
    WidgetRef ref,
    String query,
  ) async {
    if (query.trim().isEmpty) return;
    final notifier = ref.read(exploreProvider.notifier);
    await notifier.fetchApiCandidates(query);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddFoodDialog(query: query),
    );
  }
}

// ── 검색 결과 ──────────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
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
            Text('식품영양처 DB에서 직접 추가할 수 있어요',
                style: TextStyle(
                    color: c.textFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAddNew,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      '새로 추가하기',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
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
                onTap: onAddNew,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            itemBuilder: (ctx, i) => _FoodCard(food: foods[i]),
          ),
        ),
      ],
    );
  }
}

// ── 새로 추가하기 다이얼로그 ────────────────────────────────────────────────────

class _AddFoodDialog extends ConsumerWidget {
  const _AddFoodDialog({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(exploreProvider);
    final notifier = ref.read(exploreProvider.notifier);

    // 다이얼로그 가용 높이 = 화면 높이 - 키보드 - insetPadding vertical(80) - 내부 padding(40)
    final screenH = MediaQuery.of(context).size.height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final listMaxH = (screenH - keyboardH - 120 - 80)
        .clamp(80.0, screenH * 0.4);

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"$query" 검색 결과',
                          style: TextStyle(
                              color: c.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('추가할 음식을 선택하세요',
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    notifier.clearApiCandidates();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.close_rounded, color: c.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 후보 목록
            if (state.isLoadingCandidates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: c.primary)),
              )
            else if (state.apiCandidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('식품영양처 DB에서 결과를 찾지 못했어요',
                      style: TextStyle(
                          color: c.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              )
            else
              // 저장 중 전체 목록 gesture 차단
              AbsorbPointer(
                absorbing: state.isSaving,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listMaxH),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.apiCandidates.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: c.outline,
                    ),
                    itemBuilder: (ctx, i) {
                      final food = state.apiCandidates[i];
                      final isSavingThis =
                          state.savingCanonicalName == food.canonicalName;
                      return _CandidateTile(
                        food: food,
                        isSaving: isSavingThis,
                        onTap: state.isSaving
                            ? null // 저장 중이면 다른 항목 탭 차단
                            : () async {
                                Navigator.of(context).pop();
                                final ok =
                                    await notifier.saveSelectedFood(food);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? '"${food.displayName}" 추가됨'
                                          : '추가에 실패했어요'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.food,
    required this.onTap,
    this.isSaving = false,
  });

  final FoodCatalogEntity food;
  final VoidCallback? onTap;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isSaving ? 1.0 : (onTap == null ? 0.5 : 1.0),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.primary),
                      )
                    : Text(food.emoji,
                        style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.displayName,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(food.category,
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Text('  ·  ',
                          style: TextStyle(
                              color: c.textFaint, fontSize: 11)),
                      Text('1인분 ${food.nutrition.servingSizeG.round()}g',
                          style: TextStyle(
                              color: c.textFaint,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.nutrition.caloriesKcal.round()}',
                  style: TextStyle(
                      color: c.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                Text('kcal',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.add_circle_outline_rounded,
                color: c.primary, size: 20),
          ],
        ),
        ),  // Padding
      ),    // Opacity
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
                        child: Text('🔥', style: TextStyle(fontSize: 28))),
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
                (ctx, i) => _FoodCard(food: foods[i], showRank: i < 3),
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
