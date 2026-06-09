part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B top bar ────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeBTopBar extends StatelessWidget {
  const _ModeBTopBar({required this.food, required this.onBack});

  final FoodEntity food;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(children: [
            MapControlButton(
              onTap: onBack,
              child: Icon(Icons.arrow_back_rounded, size: 20, color: c.text),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceAlt, borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(food.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('내 주변 코스 찾기',
                          style: TextStyle(
                              fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700)),
                      Text('${food.name} · ${food.kcal} kcal',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B top bar (복원 전용: food가 null일 때)
// ════════════════════════════════════════════════════════════════════════════

class _ModeBNavRestoreTopBar extends StatelessWidget {
  const _ModeBNavRestoreTopBar({
    required this.foodName,
    required this.foodKcal,
    required this.onBack,
  });

  final String foodName;
  final int foodKcal;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(children: [
            MapControlButton(
              onTap: onBack,
              child: Icon(Icons.arrow_back_rounded, size: 20, color: c.text),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceAlt, borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('안내 진행 중',
                          style: TextStyle(
                              fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700)),
                      Text('$foodName · $foodKcal kcal',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B bottom panel ───────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeBBottomPanel extends StatelessWidget {
  const _ModeBBottomPanel({
    required this.scrollController,
    required this.state,
    required this.food,
    required this.pos,
    required this.isLocating,
    required this.onSearch,
    required this.onSearchFromCenter,
    required this.onLoadMore,
    required this.onTransportChange,
    required this.onCardTap,
    required this.onStartNav,
    required this.onTagToggle,
    required this.onGenerateCourse,
    required this.onGeneratedCourseTap,
  });

  final ScrollController scrollController;
  final RouteSearchState state;
  final FoodEntity food;
  final Position? pos;
  final bool isLocating;
  final VoidCallback onSearch;
  final VoidCallback onSearchFromCenter;
  final VoidCallback onLoadMore;
  final void Function(String) onTransportChange;
  final void Function(int, TouristRouteEntity) onCardTap;
  final void Function(TouristRouteEntity) onStartNav;
  final void Function(SpotTag) onTagToggle;
  final VoidCallback onGenerateCourse;
  final void Function(TouristRouteEntity) onGeneratedCourseTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: c.bg,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // ── 핸들 + 이동수단 토글 + 태그 ───────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: c.outline, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  if (!state.isLoading && !isLocating) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TransportToggle(
                                value: state.transport, onChanged: onTransportChange),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onSearchFromCenter,
                            child: Container(
                              width: 44,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.outline),
                              ),
                              child: Center(
                                child: Icon(Icons.my_location_rounded, size: 18, color: c.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── 태그 선택 ───────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 6),
                      child: _SpotTagRow(
                        selectedTags: state.selectedTags,
                        onToggle: onTagToggle,
                        onGenerateCourse: onGenerateCourse,
                        isFetching: state.isFetchingSpots,
                      ),
                    ),
                    // ── 생성된 코스 카드 (있을 때) ──────────────────────────
                    if (state.generatedCourse != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 4),
                        child: _GeneratedCourseCard(
                          course: state.generatedCourse!,
                          isSelected: state.generatedCourseSelected,
                          onTap: () => onGeneratedCourseTap(state.generatedCourse!),
                          onStart: () => onStartNav(state.generatedCourse!),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // ── 콘텐츠 ─────────────────────────────────────────────
            if (isLocating)
              SliverFillRemaining(
                child: Center(
                  child: Text('위치를 확인하는 중...',
                      style: TextStyle(
                          color: c.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              )
            else if (state.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
                ),
              )
            else if (state.routes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 36, color: c.textMuted),
                      const SizedBox(height: 12),
                      Text('현재 위치 주변 코스를 찾아보세요',
                          style: TextStyle(
                              color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.primary, borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 18, color: c.onPrimary),
                              const SizedBox(width: 8),
                              Text('주변 코스 검색',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w800,
                                      color: c.onPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pos != null ? '현재 위치 기준으로 검색합니다' : 'GPS 권한이 없어 기본 위치를 사용합니다',
                        style: TextStyle(fontSize: 11, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final route = state.routes[i];
                      final isSelected = i == state.selectedRouteIdx;
                      return _RouteCard(
                        route: route,
                        transport: state.transport,
                        isSelected: isSelected,
                        onTap: () => onCardTap(i, route),
                        onStart: isSelected ? () => onStartNav(route) : null,
                      );
                    },
                    childCount: state.routes.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, context.bottomPadding + 12),
                  child: state.isLoadingMore
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                                color: c.primary, strokeWidth: 2),
                          ),
                        )
                      : state.hasMore
                          ? GestureDetector(
                              onTap: onLoadMore,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.outline),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.expand_more_rounded, size: 18, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      '코스 더 보기 (${state.allRoutes.length - state.displayedRoutes.length}개 남음)',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: c.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(height: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Transport toggle
// ════════════════════════════════════════════════════════════════════════════

class _TransportToggle extends StatelessWidget {
  const _TransportToggle({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 36,
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _ToggleItem(
            label: '걷기',
            icon: Icons.directions_walk_rounded,
            selected: value == 'walk',
            onTap: () => onChanged('walk')),
        _ToggleItem(
            label: '자전거',
            icon: Icons.directions_bike_rounded,
            selected: value == 'bike',
            onTap: () => onChanged('bike')),
      ]),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? c.text : c.textMuted),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.text : c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Spot tag row
// ════════════════════════════════════════════════════════════════════════════

class _SpotTagRow extends StatelessWidget {
  const _SpotTagRow({
    required this.selectedTags,
    required this.onToggle,
    required this.onGenerateCourse,
    required this.isFetching,
  });

  final Set<SpotTag> selectedTags;
  final void Function(SpotTag) onToggle;
  final VoidCallback onGenerateCourse;
  final bool isFetching;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('스팟 태그',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tag in SpotTag.values) ...[
                    _SpotTagChip(
                      tag: tag,
                      selected: selectedTags.isEmpty || selectedTags.contains(tag),
                      onTap: () => onToggle(tag),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: isFetching ? null : onGenerateCourse,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isFetching ? c.surfaceAlt : c.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isFetching
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.textMuted),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 13, color: c.onPrimary),
                        const SizedBox(width: 4),
                        Text('코스 생성',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: c.onPrimary)),
                      ],
                    ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _SpotTagChip extends StatelessWidget {
  const _SpotTagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });
  final SpotTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? c.primary : c.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${tag.emoji} ${tag.label}',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? c.primary : c.textMuted),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Generated course card
// ════════════════════════════════════════════════════════════════════════════

class _GeneratedCourseCard extends StatelessWidget {
  const _GeneratedCourseCard({
    required this.course,
    required this.isSelected,
    required this.onTap,
    required this.onStart,
  });

  final TouristRouteEntity course;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.accent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('⚡ 맞춤 코스',
                    style: TextStyle(
                        fontSize: 10, color: c.accent, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(course.name,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: c.text),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              MapInfoChip(
                  icon: Icons.straighten_rounded,
                  label: '${course.distanceKm.toStringAsFixed(1)}km'),
              const SizedBox(width: 8),
              MapInfoChip(
                  icon: Icons.schedule_rounded, label: '${course.durationMinutes}분'),
              const SizedBox(width: 8),
              MapInfoChip(
                  icon: Icons.local_fire_department_rounded,
                  label: '~${course.kcal}kcal'),
              const Spacer(),
              if (course.waypoints.isNotEmpty)
                Text('${course.waypoints.length}개 스팟',
                    style: TextStyle(
                        fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
            ]),
            if (isSelected) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, size: 15, color: c.onPrimary),
                      const SizedBox(width: 6),
                      Text('안내 시작',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.onPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
