part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Kcal widget (Mode A 우측 상단) ─────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _KcalWidget extends ConsumerWidget {
  const _KcalWidget({this.routeKcal});
  final int? routeKcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walk = ref.watch(walkSessionProvider);
    return GestureDetector(
      onTap: () => context.push('/record'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥 ${walk.caloriesKcal.round()} kcal',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFF7A45))),
            if (routeKcal != null)
              Text('+$routeKcal 예상',
                  style: const TextStyle(
                      fontSize: 10, color: kMapGreen, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Long press sheet ─────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _LongPressSheet extends StatelessWidget {
  const _LongPressSheet({
    required this.latLng,
    required this.locationName,
    required this.canAddWaypoint,
    required this.onSetOrigin,
    required this.onSetDest,
    required this.onAddWaypoint,
  });

  final NLatLng latLng;
  final String locationName;
  final bool canAddWaypoint;
  final VoidCallback onSetOrigin;
  final VoidCallback onSetDest;
  final VoidCallback onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration:
                  BoxDecoration(color: kMapHandle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(locationName,
              style: const TextStyle(
                  color: kMapWhite87, fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          const Text('이 위치를 어디로 설정할까요?',
              style: TextStyle(
                  color: kMapWhite87, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            MapLocationActionBtn(
                label: '출발지',
                icon: Icons.trip_origin_rounded,
                color: const Color(0xFF7C8AFF),
                onTap: onSetOrigin),
            const SizedBox(width: 8),
            MapLocationActionBtn(
                label: '도착지',
                icon: Icons.place_rounded,
                color: const Color(0xFFFF4D6D),
                onTap: onSetDest),
            if (canAddWaypoint) ...[
              const SizedBox(width: 8),
              MapLocationActionBtn(
                  label: '경유지',
                  icon: Icons.add_location_alt_rounded,
                  color: const Color(0xFFFFC56E),
                  onTap: onAddWaypoint),
            ],
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Nearby item action sheet (탭별 추천 아이템 선택 시트) ─────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NearbyItemActionSheet extends StatelessWidget {
  const _NearbyItemActionSheet({
    required this.name,
    required this.category,
    required this.canAddWaypoint,
    required this.onSetDest,
    required this.onAddWaypoint,
    required this.onViewDetail,
  });

  final String name;
  final String? category;
  final bool canAddWaypoint;
  final VoidCallback onSetDest;
  final VoidCallback onAddWaypoint;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kMapHandle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          if (category != null && category!.isNotEmpty)
            Text(category!,
                style: const TextStyle(
                    fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
          Text(name,
              style: const TextStyle(
                  color: kMapWhite87, fontSize: 16, fontWeight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Row(children: [
            MapLocationActionBtn(
              label: '도착지',
              icon: Icons.place_rounded,
              color: const Color(0xFFFF4D6D),
              onTap: onSetDest,
            ),
            if (canAddWaypoint) ...[
              const SizedBox(width: 8),
              MapLocationActionBtn(
                label: '경유지',
                icon: Icons.add_location_alt_rounded,
                color: const Color(0xFFFFC56E),
                onTap: onAddWaypoint,
              ),
            ],
            const SizedBox(width: 8),
            MapLocationActionBtn(
              label: '자세히',
              icon: Icons.open_in_new_rounded,
              color: kMapWhite45,
              onTap: onViewDetail,
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Calorie compare panel ─────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _CalorieComparePanel extends StatelessWidget {
  const _CalorieComparePanel({
    required this.routeKcal,
    required this.destKcal,
    required this.onAddWaypoint,
  });

  final int routeKcal;
  final int destKcal;
  final VoidCallback onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final gap = destKcal - routeKcal;
    final isGood = gap.abs() <= (destKcal * AppConstants.kcalMatchTolerancePct).round();
    final needMore = gap > 0;
    final routeRatio = (routeKcal / destKcal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('칼로리 비교',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kMapWhite87)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGood
                    ? kMapGreen.withValues(alpha: 0.2)
                    : const Color(0xFFFFB547).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isGood ? '딱 맞아요 ✓' : needMore ? '$gap kcal 더 필요' : '${-gap} kcal 여유',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isGood ? kMapGreen : const Color(0xFFFFB547),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _KcalBar(label: '경로 소모', kcal: routeKcal, ratio: routeRatio, color: kMapGreen),
          const SizedBox(height: 6),
          _KcalBar(label: '음식 칼로리', kcal: destKcal, ratio: 1.0,
              color: const Color(0xFFFFB547)),
          if (!isGood && needMore) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAddWaypoint,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB547).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB547).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_location_alt_rounded, size: 15, color: Color(0xFFFFB547)),
                    SizedBox(width: 6),
                    Text('경유지 추가로 더 움직이기',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFFFFB547))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KcalBar extends StatelessWidget {
  const _KcalBar({
    required this.label,
    required this.kcal,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int kcal;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
            Text('$kcal kcal',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, constraints) {
          return Stack(children: [
            Container(
              height: 6, width: constraints.maxWidth,
              decoration: BoxDecoration(
                  color: Colors.white12, borderRadius: BorderRadius.circular(3)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: 6, width: constraints.maxWidth * ratio,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ]);
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Waypoint candidate sheet ──────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _WaypointCandidateSheet extends StatelessWidget {
  const _WaypointCandidateSheet({
    required this.state,
    required this.onAdd,
    required this.onLoadMore,
  });

  final ModeAState state;
  final ValueChanged<WaypointCandidateEntity> onAdd;
  final ValueChanged<int> onLoadMore;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration:
                  BoxDecoration(color: kMapHandle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('경유지 추천',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kMapWhite87)),
          const SizedBox(height: 4),
          const Text('경유하면 칼로리를 더 소모할 수 있는 장소예요',
              style: TextStyle(
                  fontSize: 12, color: kMapWhite45, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          if (state.loadingCandidates)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: kMapGreen, strokeWidth: 2),
              ),
            )
          else if (state.waypointCandidates.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('추천 경유지가 없습니다',
                    style: TextStyle(color: kMapWhite45, fontSize: 13)),
              ),
            )
          else
            ...state.waypointCandidates.map((c) => _WaypointCandidateCard(
                  candidate: c,
                  canAdd: state.waypoints.length < 3,
                  onAdd: () => onAdd(c),
                )),
        ],
      ),
    );
  }
}

class _WaypointCandidateCard extends StatelessWidget {
  const _WaypointCandidateCard({
    required this.candidate,
    required this.canAdd,
    required this.onAdd,
  });

  final WaypointCandidateEntity candidate;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: candidate.imageUrl != null
              ? SizedBox(
                  width: 54, height: 54,
                  child: Image.network(candidate.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon()))
              : _placeholderIcon(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kMapGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(candidate.category,
                    style: const TextStyle(
                        fontSize: 10, color: kMapGreen, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(candidate.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kMapWhite87),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(candidate.detourLabel,
                  style: const TextStyle(
                      fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w500)),
              Text('+${candidate.extraKcal} kcal 추가 소모',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFFFB547), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (canAdd)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: kMapGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kMapGreen.withValues(alpha: 0.5)),
              ),
              child: const Text('+ 경유지 추가',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: kMapGreen)),
            ),
          ),
      ]),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
          color: kMapPanelAlt, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.landscape_rounded, size: 24, color: kMapWhite45),
    );
  }
}
