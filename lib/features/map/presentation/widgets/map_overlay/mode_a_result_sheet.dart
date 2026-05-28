part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode A 결과 시트 ───────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeAResultSheet extends StatelessWidget {
  const _ModeAResultSheet({
    required this.state,
    required this.expanded,
    required this.onToggleExpand,
    required this.onRestaurantTap,
    required this.onStartNavigation,
    required this.onLoadCandidates,
    required this.onAddWaypointCandidate,
  });

  final ModeAState state;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<RestaurantEntity> onRestaurantTap;
  final VoidCallback onStartNavigation;
  final ValueChanged<int> onLoadCandidates;
  final ValueChanged<WaypointCandidateEntity> onAddWaypointCandidate;

  @override
  Widget build(BuildContext context) {
    final result = state.routeResult!;

    return Column(
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: const MapSheetHandle(),
        ),
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
                              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${result.kcalBurn}',
                              style: TextStyle(
                                  fontSize: context.wp(10.5), fontWeight: FontWeight.w800,
                                  color: kMapGreen, letterSpacing: -1.5, height: 1)),
                          const SizedBox(width: 4),
                          const Text('kcal',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: kMapWhite45)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${result.distanceKm} km · ${result.durationMinutes}분',
                          style: const TextStyle(
                              fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${result.fromName} → ${result.toName}',
                          style: const TextStyle(
                              fontSize: 12, color: kMapWhite87, fontWeight: FontWeight.w700),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kMapGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('경유 ${w.name}',
                                style: const TextStyle(
                                    fontSize: 11, color: kMapGreen, fontWeight: FontWeight.w700)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        if (state.destIsRestaurant && state.destKcal > 0) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(context.wp(5), 14, context.wp(5), 0),
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
          Padding(
            padding: EdgeInsets.fromLTRB(context.wp(5), 14, context.wp(5), 4),
            child: const Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('도착지 근처 추천 맛집',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: kMapWhite87)),
                  Text('소모 칼로리 ±20% 범위에서 추천',
                      style: TextStyle(
                          fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
                ],
              ),
            ]),
          ),
          Expanded(
            child: state.restaurants.isEmpty
                ? const Center(
                    child: Text('추천 식당이 없습니다',
                        style: TextStyle(color: kMapWhite45, fontSize: 13)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        context.wp(5), 4, context.wp(5), 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.restaurants.length,
                    itemBuilder: (ctx, i) {
                      final r = state.restaurants[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: context.wp(58),
                          child: _RestaurantCard(
                            restaurant: r,
                            routeKcal: result.kcalBurn,
                            onTap: () => onRestaurantTap(r),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
        if (result.routePoints.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.wp(5), 8, context.wp(5), 12),
              child: GestureDetector(
                onTap: onStartNavigation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: kMapGreen, borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('안내 시작',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
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
    final matchColor = match == _CalMatch.good
        ? kMapGreen
        : match == _CalMatch.tooMuch
            ? const Color(0xFFFFB547)
            : const Color(0xFF7C8AFF);

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
                              color: kMapWhite87, fontWeight: FontWeight.w800,
                              fontSize: 13, letterSpacing: -0.1),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    TinyRing(pct: matchPct, size: 26, color: matchColor,
                        label: '${matchPct.round()}'),
                  ]),
                  const SizedBox(height: 2),
                  Text('${r.menu} · 약 ${r.kcal} kcal',
                      style: const TextStyle(
                          color: kMapWhite45, fontSize: 11, fontWeight: FontWeight.w600)),
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
                          fontSize: 10, fontWeight: FontWeight.w700, color: matchColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (r.rating > 0)
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC56E)),
                      const SizedBox(width: 3),
                      Text(r.rating.toString(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: kMapWhite87)),
                      Text(' · ${r.distanceLabel}',
                          style: const TextStyle(
                              fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
                    ])
                  else
                    Text('${r.distanceLabel} · ${r.walkLabel}',
                        style: const TextStyle(
                            fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
