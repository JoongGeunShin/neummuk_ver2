import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../providers/explore_provider.dart';
import '../widgets/add_food_dialog.dart';
import '../widgets/popular_section.dart';
import '../widgets/search_results.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

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
                      context.wp(2),
                      context.hp(1),
                      context.wp(3),
                      0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/home'),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: c.text,
                            size: 20,
                          ),
                        ),
                        Text(
                          '탐색',
                          style: AppTypography.subtitle.copyWith(
                            color: c.text,
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
                              Icon(
                                Icons.search_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: notifier.setQuery,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => notifier.submitSearch(),
                                  style: AppTypography.body.copyWith(
                                    color: c.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '음식 이름으로 검색',
                                    hintStyle: TextStyle(
                                      color: c.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: c.textMuted,
                                    size: 18,
                                  ),
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
                                      : Icon(
                                          Icons.search_rounded,
                                          color: c.primary,
                                          size: 20,
                                        ),
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
                              onTap: () => notifier.setCategory(categories[i]),
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
                    ? Center(child: CircularProgressIndicator(color: c.primary))
                    : state.isSearchMode
                    ? SearchResults(
                        foods: state.results,
                        query: state.query,
                        onAddNew: () =>
                            _showAddFoodDialog(context, ref, state.query),
                      )
                    : PopularSection(foods: state.popularFoods),
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
    await ref.read(exploreProvider.notifier).fetchApiCandidates(query);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddFoodDialog(query: query),
    );
  }
}
