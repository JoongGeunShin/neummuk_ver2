part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Navigation top card (도보/자전거) ──────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavTopCard extends StatelessWidget {
  const _NavTopCard({required this.navState, required this.route});

  final ModeANavState navState;
  final RouteResultEntity route;

  IconData get _turnIcon => switch (navState.nextGuide?.type ?? 11) {
        12 => Icons.turn_right_rounded,
        13 => Icons.turn_left_rounded,
        14 => Icons.u_turn_left_rounded,
        100 => Icons.flag_rounded,
        _ => Icons.straight_rounded,
      };

  Color get _iconColor =>
      navState.nextGuide?.isArrival == true ? const Color(0xFFE74C3C) : kMapGreen;

  String get _nextDistLabel {
    final d = navState.nextGuide?.distanceM ?? 0;
    if (d <= 0) return navState.remainingLabel;
    return d < 1000 ? '${d}m' : '${(d / 1000).toStringAsFixed(1)}km';
  }

  String get _transportLabel => switch (route.transport) {
        'bike' => '🚲 자전거',
        'transit' => '🚌 대중교통',
        _ => '🚶 도보',
      };

  @override
  Widget build(BuildContext context) {
    final guide = navState.nextGuide;
    final isArrival = guide?.isArrival == true;

    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _iconColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_turnIcon, size: 30, color: _iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide?.guidance ??
                            (isArrival ? '목적지에 도착했습니다' : '경로를 따라 이동하세요'),
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: kMapWhite87, letterSpacing: -0.3, height: 1.25,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(_nextDistLabel,
                            style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900,
                              color: _iconColor, letterSpacing: -1, height: 1,
                            )),
                        const SizedBox(width: 8),
                        Text(_transportLabel,
                            style: const TextStyle(
                                fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: kMapWhite45),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${route.toName} 방향',
                    style: const TextStyle(
                        fontSize: 12, color: kMapWhite45, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('${navState.remainingLabel} · ${navState.remainingMinutes}분',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kMapWhite87)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Navigation bottom strip ───────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavBottomStrip extends StatelessWidget {
  const _NavBottomStrip({
    required this.navState,
    required this.route,
    required this.onStop,
  });

  final ModeANavState navState;
  final RouteResultEntity route;
  final VoidCallback onStop;

  double get _progress {
    final total = route.routePoints.isNotEmpty
        ? _totalDist(route.routePoints)
        : route.distanceKm * 1000;
    if (total <= 0) return 0;
    final remaining = navState.remainingDistanceM.toDouble();
    return ((total - remaining) / total).clamp(0.0, 1.0);
  }

  double _totalDist(List<LatLng> pts) {
    double d = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final dlat = (pts[i + 1].latitude - pts[i].latitude) * (3.14159 / 180);
      final dlng = (pts[i + 1].longitude - pts[i].longitude) * (3.14159 / 180);
      d += 6371000 * 2 * (dlat * dlat / 4 + dlng * dlng / 4 * (1 - dlat * dlat / 4));
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final prog = _progress;

    return Container(
      color: kMapPanel,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(kMapGreen),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${navState.remainingLabel} 남음',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: kMapWhite87)),
                Text(
                  '약 ${navState.remainingMinutes}분 · '
                  '${(route.fromName.length > 8 ? '${route.fromName.substring(0, 8)}…' : route.fromName)} → '
                  '${(route.toName.length > 8 ? '${route.toName.substring(0, 8)}…' : route.toName)}',
                  style: const TextStyle(
                      fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
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
                child: const Text('안내 종료',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Colors.redAccent)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
