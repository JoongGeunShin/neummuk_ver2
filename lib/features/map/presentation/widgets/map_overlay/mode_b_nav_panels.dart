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
    // 생성 코스(스팟 기반)는 앱 secondary 색상(pinSight)으로 차별화
    if (route.isGenerated) return const Color(0xFFFF4D6D);
    return route.type == '자전거' ? const Color(0xFFFFB547) : const Color(0xFF4A90E2);
  }

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

  Color get _accentColor {
    final route = navState.route;
    if (route == null) return const Color(0xFF4A90E2);
    if (route.isGenerated) return const Color(0xFFFF4D6D);
    return route.type == '자전거' ? const Color(0xFFFFB547) : const Color(0xFF4A90E2);
  }

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

// ══════════════════════════════════════════════════════════════════════════════
// ── Mode B 생성 코스 스팟 캐러셀 (스와이프 가능)
// ══════════════════════════════════════════════════════════════════════════════

class _ModeBNavSpotCarousel extends StatefulWidget {
  const _ModeBNavSpotCarousel({
    required this.waypoints,
    required this.activeIdx,
    required this.navState,
    required this.onPageChanged,
    required this.onStop,
  });

  final List<SpotWaypoint> waypoints;
  final int activeIdx;
  final ModeBNavState navState;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStop;

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
    const accent = Color(0xFFFF4D6D);

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
              final cur = widget.activeIdx.clamp(0, wps.length - 1);
              final status = i < cur
                  ? _SpotStatus.done
                  : i == cur
                      ? _SpotStatus.active
                      : _SpotStatus.upcoming;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _SpotWaypointCard(
                  waypoint: wps[i],
                  index: i,
                  total: wps.length,
                  status: status,
                  instruction: status == _SpotStatus.active
                      ? widget.navState.nextInstruction
                      : null,
                  onStop: widget.onStop,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        if (wps.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
    required this.onStop,
    this.instruction,
  });

  final SpotWaypoint waypoint;
  final int index;
  final int total;
  final _SpotStatus status;
  final String? instruction;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF4D6D);
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
        iconBg = Colors.white.withValues(alpha: 0.05);
        iconColor = kMapWhite45;
        icon = Icons.radio_button_unchecked_rounded;
        statusLabel = '예정';
    }

    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == _SpotStatus.active
              ? accent.withValues(alpha: 0.6)
              : Colors.white12,
          width: status == _SpotStatus.active ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 44, 10),
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
                        color: status == _SpotStatus.active ? accent : kMapWhite45,
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
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onStop,
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.close_rounded, size: 16, color: kMapWhite45),
              ),
            ),
          ),
        ],
      ),
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
    const accent = Color(0xFFFF4D6D);
    final barColor = isDone ? const Color(0xFF03C75A) : accent;

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
