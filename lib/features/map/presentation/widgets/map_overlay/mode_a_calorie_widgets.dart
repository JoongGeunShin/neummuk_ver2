part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Kcal widget (Mode A 우측 상단) ─────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _KcalWidget extends ConsumerWidget {
  const _KcalWidget({this.routeKcal});
  final int? routeKcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkKcal = ref.watch(
      walkSessionProvider.select((s) => s.caloriesKcal),
    );
    return GestureDetector(
      onTap: () => context.push('/record'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔥 ${walkKcal.round()} kcal',
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.primary,
              ),
            ),
            if (routeKcal != null)
              Text(
                '+$routeKcal 예상',
                style: AppTypography.micro.copyWith(color: kMapPrimary),
              ),
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kMapHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            locationName,
            style: AppTypography.body.copyWith(
              color: kMapWhite87,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '이 위치를 어디로 설정할까요?',
            style: AppTypography.bodyLg.copyWith(
              color: kMapWhite87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              MapLocationActionBtn(
                label: '출발지',
                icon: Icons.trip_origin_rounded,
                color: context.colors.pinUser,
                onTap: onSetOrigin,
              ),
              const SizedBox(width: 8),
              MapLocationActionBtn(
                label: '도착지',
                icon: Icons.place_rounded,
                color: context.colors.danger,
                onTap: onSetDest,
              ),
              if (canAddWaypoint) ...[
                const SizedBox(width: 8),
                MapLocationActionBtn(
                  label: '경유지',
                  icon: Icons.add_location_alt_rounded,
                  color: context.colors.accent,
                  onTap: onAddWaypoint,
                ),
              ],
            ],
          ),
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
    final needMore = gap > 0;

    return Column(
      children: [
        CalorieCompareDonut(kcalBurn: routeKcal, kcalFood: destKcal, size: 160),
        if (needMore) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAddWaypoint,
            child: Builder(
              builder: (ctx) {
                final warnColor = ctx.colors.warn;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: warnColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: warnColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_location_alt_rounded,
                        size: 15,
                        color: warnColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '경유지 추가로 더 움직이기',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: warnColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kMapHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '경유지 추천',
            style: AppTypography.bodyLg.copyWith(
              fontWeight: FontWeight.w800,
              color: kMapWhite87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '경유하면 칼로리를 더 소모할 수 있는 장소예요',
            style: AppTypography.caption.copyWith(color: kMapWhite45),
          ),
          const SizedBox(height: 14),
          if (state.loadingCandidates)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  color: kMapPrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (state.waypointCandidates.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '추천 경유지가 없습니다',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: kMapWhite45,
                  ),
                ),
              ),
            )
          else
            ...state.waypointCandidates.map(
              (c) => _WaypointCandidateCard(
                candidate: c,
                canAdd: state.waypoints.length < 3,
                onAdd: () => onAdd(c),
              ),
            ),
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: candidate.imageUrl != null
                ? SizedBox(
                    width: 54,
                    height: 54,
                    child: Image.network(
                      candidate.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(),
                    ),
                  )
                : _placeholderIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kMapPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    candidate.category,
                    style: AppTypography.micro.copyWith(
                      color: kMapPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  candidate.name,
                  style: AppTypography.bodyMute.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kMapWhite87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  candidate.detourLabel,
                  style: AppTypography.tiny.copyWith(
                    color: kMapWhite45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '+${candidate.extraKcal} kcal 추가 소모',
                  style: AppTypography.tiny.copyWith(
                    color: context.colors.warn,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canAdd)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: kMapPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kMapPrimary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '+ 경유지 추가',
                  style: AppTypography.tiny.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kMapPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.landscape_rounded, size: 24, color: kMapWhite45),
    );
  }
}
