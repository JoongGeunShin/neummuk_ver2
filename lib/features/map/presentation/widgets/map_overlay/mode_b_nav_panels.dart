part of '../map_overlay.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode B 네비게이션 상단 카드
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBNavTopCard extends StatelessWidget {
  const _ModeBNavTopCard({required this.navState});

  final ModeBNavState navState;

  Color get _accentColor {
    final route = navState.route;
    if (route == null) return const Color(0xFF4A90E2);
    return route.type == '자전거' ? const Color(0xFFFFB547) : const Color(0xFF4A90E2);
  }

  IconData get _icon {
    if (navState.remainingDistanceM < 100) return Icons.flag_rounded;
    return navState.route?.type == '자전거'
        ? Icons.directions_bike_rounded
        : Icons.directions_walk_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final kcalPct = (navState.kcalProgress * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, size: 28, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        navState.nextInstruction.isEmpty
                            ? '경로를 따라 이동하세요'
                            : navState.nextInstruction,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kMapWhite87,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                          navState.remainingLabel,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '약 ${navState.remainingMinutes}분',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 칼로리 진행 바
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 13, color: kMapWhite45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${navState.elapsedKcal.round()} / ${navState.foodKcal} kcal  ($kcalPct%)',
                      style: const TextStyle(
                          fontSize: 11,
                          color: kMapWhite45,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (navState.route != null)
                    Text(
                      navState.route!.name.length > 12
                          ? '${navState.route!.name.substring(0, 12)}…'
                          : navState.route!.name,
                      style: const TextStyle(
                          fontSize: 10,
                          color: kMapWhite45,
                          fontWeight: FontWeight.w500),
                    ),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: navState.kcalProgress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode B 네비게이션 하단 스트립
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBNavBottomStrip extends StatelessWidget {
  const _ModeBNavBottomStrip({
    required this.navState,
    required this.onStop,
  });

  final ModeBNavState navState;
  final VoidCallback onStop;

  double get _progress {
    final route = navState.route;
    if (route == null) return 0;
    final total = (route.distanceKm * 1000).clamp(1.0, double.infinity);
    final remaining = navState.remainingDistanceM.toDouble();
    return ((total - remaining) / total).clamp(0.0, 1.0);
  }

  Color get _accentColor => navState.route?.type == '자전거'
      ? const Color(0xFFFFB547)
      : const Color(0xFF4A90E2);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final accent = _accentColor;

    return Container(
      color: kMapPanel,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${navState.remainingLabel} 남음',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: kMapWhite87),
                ),
                Text(
                  '${navState.foodName.isNotEmpty ? navState.foodName : "목표"} 칼로리 ${(navState.kcalProgress * 100).toStringAsFixed(0)}% 달성',
                  style: const TextStyle(
                      fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  '안내 종료',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
