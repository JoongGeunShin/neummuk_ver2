part of '../map_overlay.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode A 도보/자전거 전체 경로 카드 (안내 시작 초기 화면)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeAWalkNavOverviewCard extends StatelessWidget {
  const _ModeAWalkNavOverviewCard({
    required this.navState,
    required this.destName,
    required this.transport,
    required this.totalDistanceM,
    required this.onStepMode,
  });

  final ModeANavState navState;
  final String destName;
  final String transport;
  final double totalDistanceM;
  final VoidCallback onStepMode;

  Color _accentColor(BuildContext context) {
    final c = context.colors;
    return c.accent;
  }

  IconData _transportIcon() => transport == 'bike'
      ? Icons.directions_bike_rounded
      : Icons.directions_walk_rounded;

  double get _progress {
    if (totalDistanceM <= 0) return 0;
    final remaining = navState.remainingDistanceM.toDouble();
    return ((totalDistanceM - remaining) / totalDistanceM).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final pctLabel = '${(_progress * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 목적지 + 남은 거리/시간 ──────────────────────────
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
                    child: Icon(_transportIcon(), size: 28, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destName.isNotEmpty ? destName : '목적지',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w800,
                            color: kMapWhite87,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              navState.remainingLabel,
                              style: AppTypography.titleSm.copyWith(
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: -1,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '약 ${navState.remainingMinutes}분',
                              style: AppTypography.tiny.copyWith(
                                color: kMapWhite45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── 단계별 전환 버튼 ──────────────────────────
                  GestureDetector(
                    onTap: onStepMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 16,
                            color: kMapWhite45,
                          ),
                          SizedBox(height: 2),
                          Text(
                            '단계별',
                            style: AppTypography.nano.copyWith(
                              color: kMapWhite45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 이동 진행도 바 ─────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 13,
                        color: accent.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '이동 중 · $pctLabel 완료',
                          style: AppTypography.tiny.copyWith(
                            color: kMapWhite45,
                          ),
                        ),
                      ),
                      Text(
                        '${navState.elapsedKcal.round()} kcal',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode A 도보/자전거 단계별 방향 전환 카드 (step-by-step 모드)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeAWalkNavTurnCard extends StatelessWidget {
  const _ModeAWalkNavTurnCard({
    required this.navState,
    required this.transport,
    required this.turnPoint,
    required this.distanceLabel,
    required this.onOverview,
  });

  final ModeANavState navState;
  final String transport;
  final TurnPoint? turnPoint;
  final String distanceLabel;
  final VoidCallback onOverview;

  Color _accentColor(BuildContext context) {
    final c = context.colors;
    return c.accent;
  }

  IconData _transportIcon() => transport == 'bike'
      ? Icons.directions_bike_rounded
      : Icons.directions_walk_rounded;

  IconData _turnIcon(TurnType? type) => switch (type) {
    TurnType.right => Icons.turn_right_rounded,
    TurnType.left => Icons.turn_left_rounded,
    TurnType.uTurn => Icons.u_turn_right_rounded,
    TurnType.arrival => Icons.flag_rounded,
    _ => _transportIcon(),
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
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
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
                          style: AppTypography.body.copyWith(
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
                          Row(
                            children: [
                              Text(
                                distanceLabel,
                                style: AppTypography.titleSm.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                  letterSpacing: -1,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '앞',
                                style: AppTypography.label.copyWith(
                                  color: kMapWhite45,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── 개요(전체경로) 전환 버튼 ─────────────────
                  GestureDetector(
                    onTap: onOverview,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 16, color: accent),
                          const SizedBox(height: 2),
                          Text(
                            '개요',
                            style: AppTypography.nano.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
                  Container(width: 1, height: 28, color: Colors.white12),
                  _ModeAWalkStatChip(
                    label: '소모 칼로리',
                    value: '${navState.elapsedKcal.round()}kcal',
                    color: accent,
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
// ── Mode A 도보/자전거 네비게이션 하단 스트립 (공통)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeAWalkNavBottomStrip extends StatelessWidget {
  const _ModeAWalkNavBottomStrip({
    required this.navState,
    required this.transport,
    required this.totalDistanceM,
    required this.onStop,
  });

  final ModeANavState navState;
  final String transport;
  final double totalDistanceM;
  final VoidCallback onStop;

  double get _progress {
    if (totalDistanceM <= 0) return 0;
    final remaining = navState.remainingDistanceM.toDouble();
    return ((totalDistanceM - remaining) / totalDistanceM).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final accent = transport == 'transit' ? c.pinUser : c.accent;
    final label = transport == 'bike'
        ? '🚲 자전거 경로'
        : transport == 'transit'
        ? '🚌 대중교통 경로'
        : '🚶 도보 경로';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
      decoration: BoxDecoration(
        color: kMapPanel,
        border: const Border(top: BorderSide(color: Colors.white12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 진행 바 ─────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.tiny.copyWith(color: kMapWhite45),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          navState.remainingLabel,
                          style: AppTypography.bodyMute.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· 약 ${navState.remainingMinutes}분',
                          style: AppTypography.caption.copyWith(
                            color: kMapWhite45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                        style: AppTypography.label.copyWith(
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
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode A 대중교통 전체 경로 개요 카드 (안내 시작 초기 화면)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeATransitNavOverviewCard extends StatelessWidget {
  const _ModeATransitNavOverviewCard({
    required this.navState,
    required this.route,
    required this.onStepMode,
  });

  final ModeANavState navState;
  final RouteResultEntity route;
  final VoidCallback onStepMode;

  double get _progress {
    final totalM = route.distanceKm * 1000;
    if (totalM <= 0) return 0;
    return ((totalM - navState.remainingDistanceM) / totalM).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = c.pinUser;
    final topPad = MediaQuery.paddingOf(context).top;
    final steps = route.transitSteps;
    final vehicleCount = steps.where((s) => s.isVehicle).length;
    final transferCount = vehicleCount > 1 ? vehicleCount - 1 : 0;
    final pctLabel = '${(_progress * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 목적지 + 남은 거리/시간 + 단계별 버튼 ─────────────
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
                    child: Icon(
                      Icons.directions_transit_rounded,
                      size: 28,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.toName.isNotEmpty ? route.toName : '목적지',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w800,
                            color: kMapWhite87,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              navState.remainingLabel,
                              style: AppTypography.titleSm.copyWith(
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: -1,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '약 ${navState.remainingMinutes}분',
                              style: AppTypography.tiny.copyWith(
                                color: kMapWhite45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onStepMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 16,
                            color: kMapWhite45,
                          ),
                          SizedBox(height: 2),
                          Text(
                            '단계별',
                            style: AppTypography.nano.copyWith(
                              color: kMapWhite45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 단계 아이콘 + 환승 정보 + 진행 바 ──────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (steps.isNotEmpty)
                    _TransitStepIconRow(steps: steps, context: context),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (transferCount > 0) ...[
                        Icon(
                          Icons.transfer_within_a_station_rounded,
                          size: 12,
                          color: accent.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '환승 $transferCount회',
                          style: AppTypography.tiny.copyWith(
                            color: kMapWhite45,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: accent.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '이동 중 · $pctLabel 완료',
                          style: AppTypography.tiny.copyWith(
                            color: kMapWhite45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
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
      ),
    );
  }
}

// ── 대중교통 단계 아이콘 행 ──────────────────────────────────────────────────────

class _TransitStepIconRow extends StatelessWidget {
  const _TransitStepIconRow({required this.steps, required this.context});

  final List<TransitStep> steps;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    final c = context.colors;
    final widgets = <Widget>[];
    final displaySteps = steps.length > 7 ? steps.sublist(0, 7) : steps;

    for (var i = 0; i < displaySteps.length; i++) {
      final step = displaySteps[i];
      if (i > 0) {
        widgets.add(
          const Icon(Icons.chevron_right_rounded, size: 13, color: kMapWhite45),
        );
      }
      final color = step.isWalk
          ? kMapWhite45
          : step.isBus
          ? kMapPrimary
          : c.pinUser;
      final icon = step.isWalk
          ? Icons.directions_walk_rounded
          : step.isBus
          ? Icons.directions_bus_rounded
          : Icons.directions_subway_rounded;

      widgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (step.isVehicle && step.lineInfo != null) ...[
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  step.lineInfo!.length > 5
                      ? '${step.lineInfo!.substring(0, 5)}..'
                      : step.lineInfo!,
                  style: AppTypography.nano.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (steps.length > 7) {
      widgets.add(
        Text(
          ' +${steps.length - 7}',
          style: AppTypography.nano.copyWith(
            fontWeight: FontWeight.w400,
            color: kMapWhite45,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
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
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.micro.copyWith(
            color: kMapWhite45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
