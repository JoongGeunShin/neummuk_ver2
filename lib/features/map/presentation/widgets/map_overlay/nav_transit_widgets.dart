part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Transit navigation card ───────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavTransitCard extends StatelessWidget {
  const _NavTransitCard({required this.navState, required this.route});

  final ModeANavState navState;
  final RouteResultEntity route;

  Color _stepColor(TransitStep step, BuildContext context) {
    final c = context.colors;
    return step.isWalk ? kMapWhite45 : step.isBus ? kMapGreen : c.pinUser;
  }

  IconData _stepIcon(TransitStep step) => step.isWalk
      ? Icons.directions_walk_rounded
      : step.isBus
          ? Icons.directions_bus_rounded
          : Icons.directions_subway_rounded;

  @override
  Widget build(BuildContext context) {
    final steps = route.transitSteps;
    if (steps.isEmpty) return _buildFallback();

    final idx     = navState.currentTransitStepIdx.clamp(0, steps.length - 1);
    final current = steps[idx];
    final next    = idx + 1 < steps.length ? steps[idx + 1] : null;
    final color   = _stepColor(current, context);

    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_stepIcon(current), size: 28, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (current.isVehicle && current.lineInfo != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(current.lineInfo!,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(current.actionLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: kMapWhite87,
                              letterSpacing: -0.3, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(current.distanceLabel,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: color, letterSpacing: -0.5, height: 1)),
                        const SizedBox(width: 8),
                        Text(
                          '· ${current.sectionTimeMin}분'
                          '${current.isVehicle && current.stationCount > 0 ? ' · ${current.stationCount}정류장' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: kMapWhite45, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10, borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${idx + 1}/${steps.length}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: kMapWhite45)),
                ),
              ],
            ),
          ),
          if (next != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(_stepIcon(next), size: 14, color: _stepColor(next, context)),
                const SizedBox(width: 6),
                const Text('다음  ',
                    style: TextStyle(fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
                if (next.isVehicle && next.lineInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _stepColor(next, context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(next.lineInfo!,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800, color: _stepColor(next, context))),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(next.actionLabel,
                      style: const TextStyle(
                          fontSize: 12, color: kMapWhite87, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(Icons.flag_rounded, size: 14, color: context.colors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${route.toName} 도착 예정',
                      style: const TextStyle(
                          fontSize: 12, color: kMapWhite87, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('${navState.remainingLabel} · ${navState.remainingMinutes}분',
                    style: const TextStyle(
                        fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMapGreen.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: kMapGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.directions_bus_rounded, size: 26, color: kMapGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('경로를 따라 이동하세요',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kMapWhite87)),
              const SizedBox(height: 2),
              Text('${navState.remainingLabel} 남음 · ${navState.remainingMinutes}분',
                  style: const TextStyle(
                      fontSize: 12, color: kMapWhite45, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Transit step dot (지도 마커 아이콘용) ──────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _TransitStepDot extends StatelessWidget {
  const _TransitStepDot({
    required this.trafficType,
    required this.lineInfo,
    required this.isActive,
    required this.isDone,
  });

  final int trafficType;
  final String? lineInfo;
  final bool isActive;
  final bool isDone;

  Color _color(BuildContext context) {
    final c = context.colors;
    return switch (trafficType) {
      0 => c.danger,
      1 => c.pinUser,
      2 => kMapGreen,
      _ => kMapWhite45,
    };
  }

  IconData get _icon => switch (trafficType) {
        0 => Icons.flag_rounded,
        1 => Icons.directions_subway_rounded,
        2 => Icons.directions_bus_rounded,
        _ => Icons.directions_walk_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final baseColor = _color(context);
    final color    = isDone ? baseColor.withValues(alpha: 0.35) : baseColor;
    final bgColor  = isDone
        ? Colors.white.withValues(alpha: 0.06)
        : color.withValues(alpha: isActive ? 0.25 : 0.15);
    final iconColor = isDone ? color.withValues(alpha: 0.5) : Colors.white;
    final iconSize  = isActive ? 22.0 : 16.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isActive)
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        Container(
          width: isActive ? 38 : 28,
          height: isActive ? 38 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: isDone ? color.withValues(alpha: 0.3) : color,
              width: isActive ? 2.5 : 1.5,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: Icon(_icon, size: iconSize, color: iconColor),
        ),
        if (isActive &&
            (trafficType == 1 || trafficType == 2) &&
            lineInfo != null &&
            lineInfo!.isNotEmpty)
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
              ),
              child: Text(
                lineInfo!.length > 6 ? '${lineInfo!.substring(0, 6)}..' : lineInfo!,
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
              ),
            ),
          ),
      ],
    );
  }
}
