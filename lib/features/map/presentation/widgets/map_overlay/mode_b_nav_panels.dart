part of '../map_overlay.dart';

// 방향 안내 타입(TurnType/TurnPoint)은 core/utils/turn_point_utils.dart의 공용 타입을
// 그대로 쓴다 (Mode A와 동일한 턴 감지 엔진 공유).

/// 맵 위에 그려지는 교차로 방향 마커 아이콘
class _TurnDirectionMarker extends StatelessWidget {
  const _TurnDirectionMarker({required this.type});
  final TurnType type;

  IconData get _icon => switch (type) {
    TurnType.right   => Icons.turn_right_rounded,
    TurnType.left    => Icons.turn_left_rounded,
    TurnType.uTurn   => Icons.u_turn_right_rounded,
    TurnType.arrival => Icons.flag_rounded,
    TurnType.straight => Icons.straight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: context.colors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(child: Icon(_icon, size: 16, color: Colors.white)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode B 네비게이션 상단 카드
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBNavTopCard extends StatelessWidget {
  const _ModeBNavTopCard({
    required this.navState,
    this.onStepMode,
  });

  final ModeBNavState navState;
  /// null이면 단계별 전환 버튼 숨김 (생성 코스에서는 사용 안 함)
  final VoidCallback? onStepMode;

  Color _accentColor(BuildContext context) => context.colors.accent;

  IconData get _icon {
    if (navState.remainingDistanceM < 100) return Icons.flag_rounded;
    final route = navState.route;
    if (route?.isGenerated ?? false) return Icons.place_rounded;
    return route?.type == '자전거'
        ? Icons.directions_bike_rounded
        : Icons.directions_walk_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
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
                if (onStepMode != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onStepMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, size: 16, color: kMapWhite45),
                          SizedBox(height: 2),
                          Text(
                            '단계별',
                            style: TextStyle(
                              fontSize: 9,
                              color: kMapWhite45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 칼로리 진행 바
          Container(
            decoration: BoxDecoration(
              color: kMapPanelAlt,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
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

  Color _accentColor(BuildContext context) => context.colors.accent;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final accent = _accentColor(context);

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
                  color: context.colors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.danger.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '안내 종료',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.colors.danger),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode B 생성 코스 스팟 캐러셀 (스와이프 가능)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBNavSpotCarousel extends StatefulWidget {
  const _ModeBNavSpotCarousel({
    required this.waypoints,
    required this.activeIdx,
    required this.navState,
    required this.onPageChanged,
    this.onStepMode,
    this.showAllSegments = false,
    this.onShowAllToggle,
    this.onSpotTap,
  });

  final List<SpotWaypoint> waypoints;
  final int activeIdx;
  final ModeBNavState navState;
  final ValueChanged<int> onPageChanged;
  /// null이면 단계별 버튼 숨김 (교차로 turn 미감지 시)
  final VoidCallback? onStepMode;
  /// 전체 경로 표시 여부
  final bool showAllSegments;
  /// 전체/현재 구간 토글
  final VoidCallback? onShowAllToggle;
  /// 스팟 카드 탭 시 호출
  final ValueChanged<SpotWaypoint>? onSpotTap;

  @override
  State<_ModeBNavSpotCarousel> createState() => _ModeBNavSpotCarouselState();
}

class _ModeBNavSpotCarouselState extends State<_ModeBNavSpotCarousel> {
  late final PageController _pc;
  int _visiblePage = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.activeIdx.clamp(0, widget.waypoints.length - 1);
    _pc = PageController(initialPage: initial);
    _visiblePage = initial;
  }

  @override
  void didUpdateWidget(_ModeBNavSpotCarousel old) {
    super.didUpdateWidget(old);
    if (old.activeIdx != widget.activeIdx && _pc.hasClients) {
      final target = widget.activeIdx.clamp(0, widget.waypoints.length - 1);
      setState(() => _visiblePage = target);
      _pc.animateToPage(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wps = widget.waypoints;
    if (wps.isEmpty) return const SizedBox.shrink();
    final accent = context.colors.secondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 106,
          child: PageView.builder(
            controller: _pc,
            itemCount: wps.length,
            onPageChanged: (idx) {
              setState(() => _visiblePage = idx);
              widget.onPageChanged(idx);
            },
            itemBuilder: (ctx, i) {
              final viewedPage = widget.activeIdx.clamp(0, wps.length - 1);
              // GPS 진행 기준 status (text/icon 용)
              final navCur = widget.navState.currentWaypointIdx.clamp(0, wps.length - 1);
              final navStatus = i < navCur
                  ? _SpotStatus.done
                  : i == navCur
                      ? _SpotStatus.active
                      : _SpotStatus.upcoming;
              final segs = widget.navState.segmentDistancesM;
              final segDistM = (segs.length > i) ? segs[i] : null;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _SpotWaypointCard(
                  waypoint: wps[i],
                  index: i,
                  total: wps.length,
                  status: navStatus,
                  isViewedInCarousel: i == viewedPage,
                  // GPS 목표 카드에만 실거리 instruction 표시
                  instruction: i == navCur
                      ? widget.navState.nextInstruction
                      : null,
                  segmentDistM: segDistM,
                  onTap: widget.onSpotTap != null
                      ? () => widget.onSpotTap!(wps[i])
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            // dot indicator (flex로 중앙 배치)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (wps.length > 1)
                    for (int i = 0; i < wps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: i == _visiblePage ? 18 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == _visiblePage ? accent : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                ],
              ),
            ),
            // 전체 경로 토글 버튼
            if (widget.onShowAllToggle != null)
              GestureDetector(
                onTap: widget.onShowAllToggle,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.showAllSegments
                        ? accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: widget.showAllSegments
                        ? Border.all(color: accent.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 13,
                          color: widget.showAllSegments ? accent : kMapWhite45),
                      const SizedBox(width: 4),
                      Text(
                        '전체 경로',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.showAllSegments ? accent : kMapWhite45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 단계별 버튼 (교차로 turn이 있을 때만)
            if (widget.onStepMode != null)
              GestureDetector(
                onTap: widget.onStepMode,
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_rounded, size: 13, color: kMapWhite45),
                      SizedBox(width: 4),
                      Text(
                        '단계별',
                        style: TextStyle(
                          fontSize: 10,
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
        // 칼로리 게이지바
        if (widget.navState.foodKcal > 0) ...[
          const SizedBox(height: 8),
          _KcalGaugeBar(navState: widget.navState),
        ],
      ],
    );
  }
}

enum _SpotStatus { done, active, upcoming }

class _SpotWaypointCard extends StatelessWidget {
  const _SpotWaypointCard({
    required this.waypoint,
    required this.index,
    required this.total,
    required this.status,
    this.instruction,
    this.isViewedInCarousel = false,
    this.segmentDistM,
    this.onTap,
  });

  final SpotWaypoint waypoint;
  final int index;
  final int total;
  final _SpotStatus status;
  final String? instruction;
  /// 캐러셀에서 현재 보고 있는 카드 여부 — border 하이라이트에만 사용
  final bool isViewedInCarousel;
  /// 이 스팟까지의 구간 거리(m) — 예상 시간 표시용
  final double? segmentDistM;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.secondary;
    // border/강조는 GPS 목표 카드 OR 캐러셀에서 현재 보고 있는 카드
    final bool isHighlighted = status == _SpotStatus.active || isViewedInCarousel;

    final Color iconBg;
    final Color iconColor;
    final IconData icon;
    final String statusLabel;

    switch (status) {
      case _SpotStatus.done:
        iconBg = Colors.white12;
        iconColor = kMapWhite45;
        icon = Icons.check_circle_rounded;
        statusLabel = '완료';
      case _SpotStatus.active:
        iconBg = accent.withValues(alpha: 0.18);
        iconColor = accent;
        icon = Icons.place_rounded;
        statusLabel = '현재 목적지';
      case _SpotStatus.upcoming:
        iconBg = isViewedInCarousel
            ? accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05);
        iconColor = isViewedInCarousel ? accent.withValues(alpha: 0.75) : kMapWhite45;
        icon = Icons.radio_button_unchecked_rounded;
        statusLabel = '예정';
    }

    String? etaLabel;
    // active 카드는 instruction(남은거리)이 이미 있으므로 eta 숨김
    if (segmentDistM != null && segmentDistM! > 0 && status == _SpotStatus.upcoming) {
      final mins = (segmentDistM! / 83.3).ceil();
      etaLabel = '~$mins분';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kMapPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? accent.withValues(alpha: 0.6) : Colors.white12,
            width: isHighlighted ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: status == _SpotStatus.active
                            ? accent.withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Icon(icon, size: 28, color: iconColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${index + 1}/$total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isHighlighted ? accent : kMapWhite45,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waypoint.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kMapWhite87,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instruction != null && instruction!.isNotEmpty
                          ? instruction!
                          : statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: status == _SpotStatus.active
                            ? accent.withValues(alpha: 0.85)
                            : kMapWhite45,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (etaLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  etaLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? accent.withValues(alpha: 0.8) : kMapWhite45,
                  ),
                ),
              ],
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: isHighlighted ? accent.withValues(alpha: 0.7) : kMapWhite45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── 도착 완료 다이얼로그 통계 칩
// ══════════════════════════════════════════════════════════════════════════════

class _ArrivalStatChip extends StatelessWidget {
  const _ArrivalStatChip({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── 칼로리 게이지바
// ══════════════════════════════════════════════════════════════════════════════

class _KcalGaugeBar extends StatelessWidget {
  const _KcalGaugeBar({required this.navState});
  final ModeBNavState navState;

  @override
  Widget build(BuildContext context) {
    final pct = navState.kcalProgress;
    final consumed = navState.elapsedKcal.round();
    final total = navState.foodKcal;
    final isDone = pct >= 1.0;
    final accent = context.colors.secondary;
    final barColor = isDone ? context.colors.success : accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.local_fire_department_rounded,
                size: 15,
                color: barColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  navState.foodName.isNotEmpty ? navState.foodName : '목표 칼로리',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kMapWhite87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                isDone ? '달성! 🎉' : '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '소비 $consumed kcal',
                style: const TextStyle(
                  fontSize: 10,
                  color: kMapWhite45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '목표 $total kcal',
                style: const TextStyle(
                  fontSize: 10,
                  color: kMapWhite45,
                  fontWeight: FontWeight.w600,
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
// ── 단계별 방향 안내 카드 (GPX 코스 step-by-step 모드)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBTurnBar extends StatelessWidget {
  const _ModeBTurnBar({
    required this.turnType,
    required this.distanceLabel,
    required this.instruction,
    required this.navState,
    required this.onOverview,
  });

  final TurnType turnType;
  final String distanceLabel;
  final String instruction;
  final ModeBNavState navState;
  final VoidCallback onOverview;

  Color _accentColor(BuildContext context) => context.colors.accent;

  IconData get _turnIcon => switch (turnType) {
    TurnType.right    => Icons.turn_right_rounded,
    TurnType.left     => Icons.turn_left_rounded,
    TurnType.uTurn    => Icons.u_turn_right_rounded,
    TurnType.arrival  => Icons.flag_rounded,
    TurnType.straight => Icons.straight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
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
                  child: Icon(_turnIcon, size: 30, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instruction,
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
                          distanceLabel,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onOverview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                          style: TextStyle(
                            fontSize: 9,
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
          // 칼로리 진행 바
          Container(
            decoration: BoxDecoration(
              color: kMapPanelAlt,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
