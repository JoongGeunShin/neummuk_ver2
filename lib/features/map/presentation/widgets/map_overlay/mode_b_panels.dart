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
    required this.cartCount,
    required this.isLocating,
    required this.onLoadMore,
    required this.onTransportChange,
    required this.onSpotTagTap,
    required this.onNearbyCourseTap,
    required this.onSpotItemTap,
    required this.onCardTap,
    required this.onStartNav,
    required this.onGeneratedCourseTap,
    required this.onHandleTap,
    required this.generateBarHeight,
  });

  final ScrollController scrollController;
  final RouteSearchState state;
  final FoodEntity food;
  final int cartCount;
  final bool isLocating;
  final VoidCallback onLoadMore;
  final void Function(String) onTransportChange;
  final void Function(SpotTag) onSpotTagTap;
  final VoidCallback onNearbyCourseTap;
  final void Function(int, SpotEntity) onSpotItemTap;
  final void Function(int, TouristRouteEntity) onCardTap;
  final void Function(TouristRouteEntity) onStartNav;
  final void Function(TouristRouteEntity) onGeneratedCourseTap;
  /// sheet 최소화 상태에서 핸들 탭 시 호출 — sheet를 기본 크기로 올림
  final VoidCallback onHandleTap;
  /// 외부 CourseGenerateBar 높이 (하단 패딩용)
  final double generateBarHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: c.bg,
        child: Column(
          children: [
            // ── 스크롤 영역 ─────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // ── 핸들 + 이동수단 토글 + 태그 ───────────────────
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: onHandleTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 6),
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                  color: c.outline, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!state.isLoading && !isLocating) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 8),
                            child: _TransportToggle(
                              value: state.transport,
                              onChanged: onTransportChange,
                            ),
                          ),
                          // ── 태그 선택 ─────────────────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 10),
                            child: _SpotTagRow(
                              activeSpotTag: state.activeSpotTag,
                              nearbyCoursesActive: state.nearbyCoursesActive,
                              isFetching: state.isFetchingSpots || state.isLoading,
                              onSpotTagTap: onSpotTagTap,
                              onNearbyCourseTap: onNearbyCourseTap,
                            ),
                          ),
                          // ── 생성된 코스 카드 (있을 때) ────────────
                          if (state.generatedCourse != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), 8),
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

                  // ── 콘텐츠 영역 ────────────────────────────────────
                  if (isLocating)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('위치를 확인하는 중...',
                            style: TextStyle(
                                color: c.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    )
                  else if (state.isLoading || state.isFetchingSpots)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
                      ),
                    )
                  // ── 스팟 목록 (스팟 태그 선택 시) ─────────────────
                  else if (state.activeSpotTag != null) ...[
                    if (state.searchedSpots.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 36, color: c.textMuted),
                              const SizedBox(height: 12),
                              Text('주변에 ${state.activeSpotTag!.label}이 없어요',
                                  style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final spot = state.searchedSpots[i];
                              return _SpotListItem(
                                spot: spot,
                                isSelected: i == state.selectedSpotIdx,
                                onTap: () => onSpotItemTap(i, spot),
                              );
                            },
                            childCount: state.searchedSpots.length,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: context.bottomPadding + generateBarHeight + 8)),
                  ]
                  // ── 기성 코스 목록 (주변 코스 선택 시) ────────────
                  else if (state.nearbyCoursesActive) ...[
                    if (state.routes.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined, size: 36, color: c.textMuted),
                              const SizedBox(height: 12),
                              Text('주변 코스를 찾는 중이에요',
                                  style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
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
                          padding: EdgeInsets.fromLTRB(12, 4, 12, context.bottomPadding + generateBarHeight + 12),
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
                                            Icon(Icons.expand_more_rounded,
                                                size: 18, color: c.textMuted),
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
                  ]
                  // ── 빈 상태 (아무것도 선택 안 됨) ─────────────────
                  else
                    SliverFillRemaining(

                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 36, color: c.textMuted),
                            const SizedBox(height: 12),
                            Text('태그를 선택해 스팟을 찾아보세요',
                                style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('또는 🔍 주변 코스로 기성 코스를 검색해보세요',
                                style: TextStyle(fontSize: 11, color: c.textFaint)),
                          ],
                        ),
                      ),
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
    required this.activeSpotTag,
    required this.nearbyCoursesActive,
    required this.isFetching,
    required this.onSpotTagTap,
    required this.onNearbyCourseTap,
  });

  final SpotTag? activeSpotTag;
  final bool nearbyCoursesActive;
  final bool isFetching;
  final void Function(SpotTag) onSpotTagTap;
  final VoidCallback onNearbyCourseTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('스팟 태그',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in SpotTag.values) ...[
                _SpotTagChip(
                  tag: tag,
                  selected: activeSpotTag == tag,
                  onTap: isFetching ? () {} : () => onSpotTagTap(tag),
                ),
                const SizedBox(width: 6),
              ],
              // 주변 코스 특수 태그
              _NearbyCoursesChip(
                selected: nearbyCoursesActive,
                isFetching: isFetching && nearbyCoursesActive,
                onTap: isFetching && nearbyCoursesActive ? () {} : onNearbyCourseTap,
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.primary : c.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${tag.emoji} ${tag.label}',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? c.primary : c.textMuted),
        ),
      ),
    );
  }
}

class _NearbyCoursesChip extends StatelessWidget {
  const _NearbyCoursesChip({
    required this.selected,
    required this.isFetching,
    required this.onTap,
  });
  final bool selected;
  final bool isFetching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.15) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.accent : c.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: isFetching
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              )
            : Text(
                '🔍 주변 코스',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? c.accent : c.textMuted),
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Spot list item
// ════════════════════════════════════════════════════════════════════════════

class _SpotListItem extends StatelessWidget {
  const _SpotListItem({
    required this.spot,
    required this.isSelected,
    required this.onTap,
  });

  final SpotEntity spot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? c.primary.withValues(alpha: 0.15) : c.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _tagEmoji(spot.type),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? c.primary : c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (spot.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      spot.address!,
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (spot.distanceFromUserM != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      spot.distanceFromUserM! < 1000
                          ? '${spot.distanceFromUserM}m'
                          : '${(spot.distanceFromUserM! / 1000).toStringAsFixed(1)}km',
                      style: TextStyle(
                          fontSize: 11, color: c.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  String _tagEmoji(String type) {
    switch (type) {
      case 'tourist_sight': return '🏛️';
      case 'culture': return '🎭';
      case 'event': return '🎉';
      case 'sports': return '⛹️';
      case 'shopping': return '🛍️';
      default: return '📍';
    }
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
                Text('${course.waypoints.where((w) => w.type != '출발지').length}개 스팟',
                    style: TextStyle(
                        fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
            ]),
            if (course.waypoints.where((w) => w.type != '출발지').isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                course.waypoints
                    .where((w) => w.type != '출발지')
                    .map((w) => w.name)
                    .join(' → '),
                style: TextStyle(
                    fontSize: 11,
                    color: c.textMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

// ════════════════════════════════════════════════════════════════════════════
// ── 코스 생성 하단 바
// ════════════════════════════════════════════════════════════════════════════

class _CourseGenerateBar extends StatelessWidget {
  const _CourseGenerateBar({
    required this.cartCount,
    required this.isGenerating,
    required this.onGenerate,
  });

  final int cartCount;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, context.bottomPadding + 10),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.outline, width: 0.5)),
      ),
      child: GestureDetector(
        onTap: isGenerating ? null : onGenerate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isGenerating ? c.surfaceAlt : c.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: isGenerating
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.textMuted),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: c.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      cartCount > 0 ? '담은 스팟으로 코스 생성' : '스팟으로 코스 생성',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.onPrimary),
                    ),
                    if (cartCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$cartCount개',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: c.onPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B 칼로리 미니바 (탐색 중 상시 표시)
// ════════════════════════════════════════════════════════════════════════════

class _ModeBKcalMiniBar extends StatelessWidget {
  const _ModeBKcalMiniBar({
    required this.todayKcal,
    required this.targetKcal,
  });

  final double todayKcal;
  final int targetKcal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = targetKcal > 0
        ? (todayKcal / targetKcal).clamp(0.0, 1.0)
        : 0.0;
    final isDone = pct >= 1.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.bg,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.local_fire_department_rounded,
            size: 14,
            color: isDone ? Colors.green : c.primary,
          ),
          const SizedBox(width: 6),
          Text('오늘 소모',
              style: TextStyle(
                  fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: c.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(isDone ? Colors.green : c.primary),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${todayKcal.round()}/${targetKcal}kcal ($pctLabel)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDone ? Colors.green : c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 장바구니 FAB
// ════════════════════════════════════════════════════════════════════════════

class _CartFab extends StatefulWidget {
  const _CartFab({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  State<_CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<_CartFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CartFab old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count && widget.count > old.count) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: c.bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: c.outline, width: 0.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(Icons.shopping_cart_rounded, color: c.primary, size: 22),
              ),
              if (widget.count > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.count}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: c.onPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
