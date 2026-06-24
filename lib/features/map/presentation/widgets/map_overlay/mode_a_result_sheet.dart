part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode A 결과 시트 ───────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeAResultSheet extends StatelessWidget {
  const _ModeAResultSheet({
    required this.scrollController,
    required this.state,
    required this.onRestaurantTap,
    required this.onStartNavigation,
    required this.onLoadCandidates,
    required this.onAddWaypointCandidate,
    required this.onSwitchTab,
    required this.onPlaceTap,
    required this.onDurunubiTap,
  });

  final ScrollController scrollController;
  final ModeAState state;
  final ValueChanged<RestaurantEntity> onRestaurantTap;
  final VoidCallback onStartNavigation;
  final ValueChanged<int> onLoadCandidates;
  final ValueChanged<WaypointCandidateEntity> onAddWaypointCandidate;
  final ValueChanged<ModeANearbyTab> onSwitchTab;
  final ValueChanged<PlaceEntity> onPlaceTap;
  final ValueChanged<TouristRouteEntity> onDurunubiTap;

  @override
  Widget build(BuildContext context) {
    final result = state.routeResult!;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kMapPanel,
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, -12)),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MapSheetHandle(),
                  // 경로 요약
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.wp(5)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('예상 소모',
                                    style: TextStyle(
                                        fontSize: 11, color: kMapWhite45,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3)),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('${result.kcalBurn}',
                                        style: TextStyle(
                                            fontSize: context.wp(10.5),
                                            fontWeight: FontWeight.w800,
                                            color: kMapPrimary,
                                            letterSpacing: -1.5,
                                            height: 1)),
                                    const SizedBox(width: 4),
                                    const Text('kcal',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: kMapWhite45)),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${result.distanceKm} km · ${result.durationMinutes}분',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kMapWhite45,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('${result.fromName} → ${result.toName}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: kMapWhite87,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                        if (result.waypoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: result.waypoints
                                .map((w) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: kMapPrimary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('경유 ${w.name}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: kMapPrimary,
                                              fontWeight: FontWeight.w700)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 칼로리 비교 or 탭 콘텐츠
                  if (state.destIsRestaurant && state.destKcal > 0) ...[
                    Padding(
                      padding:
                          EdgeInsets.fromLTRB(context.wp(5), 14, context.wp(5), 0),
                      child: _CalorieComparePanel(
                        routeKcal: result.kcalBurn,
                        destKcal: state.destKcal,
                        onAddWaypoint: () {
                          final gap = state.destKcal - result.kcalBurn;
                          if (gap > 0) onLoadCandidates(gap);
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    // 탭 바
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: context.wp(5)),
                        itemCount: ModeANearbyTab.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final tab = ModeANearbyTab.values[i];
                          final selected = state.nearbyTab == tab;
                          return GestureDetector(
                            onTap: () => onSwitchTab(tab),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 0),
                              decoration: BoxDecoration(
                                color: selected
                                    ? kMapPrimary.withValues(alpha: 0.9)
                                    : kMapPanelAlt,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? kMapPrimary
                                      : Colors.white12,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : kMapWhite45,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 탭 콘텐츠
                    SizedBox(
                      height: 220,
                      child: _NearbyTabContent(
                        state: state,
                        onRestaurantTap: onRestaurantTap,
                        onPlaceTap: onPlaceTap,
                        onDurunubiTap: onDurunubiTap,
                        routeKcal: result.kcalBurn,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (result.routePoints.isNotEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          context.wp(5), 8, context.wp(5), 12),
                      child: GestureDetector(
                        onTap: onStartNavigation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: kMapPrimary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('안내 시작',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 탭별 콘텐츠 ────────────────────────────────────────────────────────────────

class _NearbyTabContent extends StatelessWidget {
  const _NearbyTabContent({
    required this.state,
    required this.onRestaurantTap,
    required this.onPlaceTap,
    required this.onDurunubiTap,
    required this.routeKcal,
  });

  final ModeAState state;
  final ValueChanged<RestaurantEntity> onRestaurantTap;
  final ValueChanged<PlaceEntity> onPlaceTap;
  final ValueChanged<TouristRouteEntity> onDurunubiTap;
  final int routeKcal;

  @override
  Widget build(BuildContext context) {
    if (state.nearbyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kMapPrimary, strokeWidth: 2),
      );
    }

    switch (state.nearbyTab) {
      case ModeANearbyTab.restaurant:
        if (state.restaurants.isEmpty) {
          return _emptyHint('추천 식당이 없습니다');
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width * 0.05, 4,
              MediaQuery.sizeOf(context).width * 0.05, 8),
          itemCount: state.restaurants.length,
          itemBuilder: (ctx, i) {
            final r = state.restaurants[i];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.58,
                child: _RestaurantCard(
                  restaurant: r,
                  routeKcal: routeKcal,
                  onTap: () => onRestaurantTap(r),
                ),
              ),
            );
          },
        );

      case ModeANearbyTab.durunubi:
        if (state.nearbyDurunubi.isEmpty) {
          return _emptyHint('근처 두루누비 코스가 없습니다');
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width * 0.05, 4,
              MediaQuery.sizeOf(context).width * 0.05, 8),
          itemCount: state.nearbyDurunubi.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.62,
              child: _DurunubiCourseCard(
                course: state.nearbyDurunubi[i],
                onTap: () => onDurunubiTap(state.nearbyDurunubi[i]),
              ),
            ),
          ),
        );

      default:
        // TourAPI 탭 (관광지·문화시설·축제·여행코스)
        if (state.nearbyPlaces.isEmpty) {
          return _emptyHint('${state.nearbyTab.label} 정보가 없습니다');
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width * 0.05, 4,
              MediaQuery.sizeOf(context).width * 0.05, 8),
          itemCount: state.nearbyPlaces.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.56,
              child: _PlaceCard(
                place: state.nearbyPlaces[i],
                onTap: () => onPlaceTap(state.nearbyPlaces[i]),
              ),
            ),
          ),
        );
    }
  }

  Widget _emptyHint(String msg) => Center(
        child: Text(msg,
            style: const TextStyle(color: kMapWhite45, fontSize: 13)),
      );
}

// ── TourAPI 장소 카드 ──────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});
  final PlaceEntity place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 or 플레이스홀더
          if (place.imageUrl != null && place.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: place.imageUrl!,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _imgPlaceholder(90),
            )
          else
            _imgPlaceholder(90),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: kMapPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(place.category!,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kMapPrimary)),
                    ),
                  const SizedBox(height: 5),
                  Text(place.name,
                      style: const TextStyle(
                          color: kMapWhite87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (place.address != null && place.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(place.address!,
                        style: const TextStyle(
                            color: kMapWhite45,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _imgPlaceholder(double h) => Container(
        height: h,
        color: kMapPanelAlt,
        child: const Center(
            child: Icon(Icons.place_rounded, color: kMapWhite45, size: 28)),
      );
}

// ── 두루누비 코스 카드 ─────────────────────────────────────────────────────────

class _DurunubiCourseCard extends StatelessWidget {
  const _DurunubiCourseCard({required this.course, required this.onTap});
  final TouristRouteEntity course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = course.imageUrls.isNotEmpty ? course.imageUrls.first : null;
    final tag = course.tags.isNotEmpty ? course.tags.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (img != null)
            CachedNetworkImage(
              imageUrl: img,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _imgPlaceholder(90),
            )
          else
            _imgPlaceholder(90),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Builder(builder: (ctx) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: ctx.colors.pinUser.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('두루누비',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ctx.colors.pinUser)),
                    )),
                    if (tag != null) ...[
                      const SizedBox(width: 5),
                      Text('난이도 $tag',
                          style: const TextStyle(
                              fontSize: 10,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Text(course.name,
                      style: const TextStyle(
                          color: kMapWhite87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(children: [
                    if (course.distanceKm > 0) ...[
                      const Icon(Icons.straighten_rounded,
                          size: 11, color: kMapWhite45),
                      const SizedBox(width: 3),
                      Text('${course.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                    ],
                    if (course.kcal > 0) ...[
                      const Icon(Icons.local_fire_department_rounded,
                          size: 11, color: kMapPrimary),
                      const SizedBox(width: 3),
                      Text('${course.kcal} kcal',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kMapPrimary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _imgPlaceholder(double h) => Container(
        height: h,
        color: kMapPanelAlt,
        child: const Center(
            child: Icon(Icons.hiking_rounded, color: kMapWhite45, size: 28)),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Restaurant card ───────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

enum _CalMatch { good, tooMuch, tooLittle }

_CalMatch _calMatch(int rKcal, int routeKcal) {
  if (routeKcal <= 0) return _CalMatch.good;
  final ratio = rKcal / routeKcal;
  if (ratio >= 0.80 && ratio <= 1.20) return _CalMatch.good;
  return ratio > 1.20 ? _CalMatch.tooMuch : _CalMatch.tooLittle;
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.routeKcal,
    required this.onTap,
  });

  final RestaurantEntity restaurant;
  final int routeKcal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final match = _calMatch(r.kcal, routeKcal);
    final ratio = routeKcal > 0 ? r.kcal / routeKcal : 1.0;
    final matchPct = (100 - (1 - ratio).abs() * 100).clamp(0.0, 100.0);
    final c = context.colors;
    final matchColor = match == _CalMatch.good
        ? c.success
        : match == _CalMatch.tooMuch
            ? c.warn
            : c.pinUser;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kMapPanelAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImageWidget(
              type: FoodImageWidget.fromString(r.imageType),
              height: 80,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(r.name,
                          style: const TextStyle(
                              color: kMapWhite87,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: -0.1),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    TinyRing(
                        pct: matchPct,
                        size: 26,
                        color: matchColor,
                        label: '${matchPct.round()}'),
                  ]),
                  const SizedBox(height: 2),
                  Text('${r.menu} · 약 ${r.kcal} kcal',
                      style: const TextStyle(
                          color: kMapWhite45,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      match == _CalMatch.good
                          ? '딱 맞아요 ✓'
                          : match == _CalMatch.tooMuch
                              ? '더 움직여야 해요'
                              : '여유 있어요',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: matchColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (r.rating > 0)
                    Row(children: [
                      Icon(Icons.star_rounded,
                          size: 11, color: c.accent),
                      const SizedBox(width: 3),
                      Text(r.rating.toString(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kMapWhite87)),
                      Text(' · ${r.distanceLabel}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w600)),
                    ])
                  else
                    Text('${r.distanceLabel} · ${r.walkLabel}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: kMapWhite45,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
