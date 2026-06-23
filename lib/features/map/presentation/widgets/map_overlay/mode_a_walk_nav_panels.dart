part of '../map_overlay.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode A 도보/자전거 네비게이션 상단 카드 (Mode B 스타일)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeAWalkNavTopCard extends StatelessWidget {
  const _ModeAWalkNavTopCard({
    required this.navState,
    required this.transport,
    required this.turnPoint,
    required this.distanceLabel,
    required this.onClose,
  });

  final ModeANavState navState;
  final String transport;
  final _TurnPoint? turnPoint;
  final String distanceLabel;
  final VoidCallback onClose;

  Color _accentColor(BuildContext context) {
    final c = context.colors;
    return transport == 'bike' ? c.warn : c.primary;
  }

  IconData _transportIcon() => transport == 'bike'
      ? Icons.directions_bike_rounded
      : Icons.directions_walk_rounded;

  IconData _turnIcon(_TurnType? type) => switch (type) {
    _TurnType.right   => Icons.turn_right_rounded,
    _TurnType.left    => Icons.turn_left_rounded,
    _TurnType.uTurn   => Icons.u_turn_right_rounded,
    _TurnType.arrival => Icons.flag_rounded,
    _              => _transportIcon(),
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final turn = turnPoint;
    final topPad = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 0),
      child: Container(
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
            // ── 방향 안내 ──────────────────────────────────────
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
                    child: Icon(_turnIcon(turn?.type), size: 28, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turn?.instruction ?? '경로를 따라 이동하세요',
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
                        if (distanceLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(
                              distanceLabel,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: -1,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '앞',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kMapWhite45,
                              ),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kMapPanelAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: kMapWhite45),
                    ),
                  ),
                ],
              ),
            ),
            // ── 남은 거리 / 시간 ───────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ModeAWalkStatChip(
                    label: '남은 거리',
                    value: navState.remainingLabel,
                    color: accent,
                  ),
                  Container(width: 1, height: 28, color: Colors.white12),
                  _ModeAWalkStatChip(
                    label: '남은 시간',
                    value: '약 ${navState.remainingMinutes}분',
                    color: kMapWhite87,
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

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode A 도보/자전거 네비게이션 하단 스트립
// ══════════════════════════════════════════════════════════════════════════════

class _ModeAWalkNavBottomStrip extends StatelessWidget {
  const _ModeAWalkNavBottomStrip({
    required this.navState,
    required this.transport,
    required this.onStop,
  });

  final ModeANavState navState;
  final String transport;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final accent = transport == 'bike' ? c.warn : c.primary;
    final label = transport == 'bike' ? '🚲 자전거 경로' : '🚶 도보 경로';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: kMapPanel,
        border: const Border(top: BorderSide(color: Colors.white12)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kMapWhite45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.local_fire_department_rounded, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    navState.remainingLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· 약 ${navState.remainingMinutes}분',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kMapWhite45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onStop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, size: 16, color: c.danger),
                  const SizedBox(width: 6),
                  Text(
                    '안내 종료',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── stat chip ──────────────────────────────────────────────────────────────────

class _ModeAWalkStatChip extends StatelessWidget {
  const _ModeAWalkStatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: kMapWhite45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
