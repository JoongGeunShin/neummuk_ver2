part of '../map_overlay.dart';

// ── Guide type helpers ───────────────────────────────────────────────────────

Color _navAccentColor(String transport) => switch (transport) {
      'bike' => const Color(0xFFFFB547),
      'transit' => const Color(0xFF4A90E2),
      _ => kMapGreen,
    };

IconData _guideIconForType(int type, String guidance) {
  if (guidance.contains('횡단보도')) return Icons.transfer_within_a_station_rounded;
  return switch (type) {
    0 => Icons.trip_origin_rounded,
    12 => Icons.turn_right_rounded,
    13 => Icons.turn_left_rounded,
    14 => Icons.u_turn_left_rounded,
    100 => Icons.flag_rounded,
    _ => Icons.straight_rounded,
  };
}

String _guideTurnText(int type, String guidance) {
  if (guidance.contains('횡단보도')) return '횡단보도 건너기';
  return switch (type) {
    0 => '출발',
    12 => '우회전',
    13 => '좌회전',
    14 => 'U턴',
    100 => '목적지 도착',
    _ => '직진',
  };
}

// ════════════════════════════════════════════════════════════════════════════
// ── Navigation guide carousel (swipeable turn-by-turn) ───────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavGuideCarousel extends StatefulWidget {
  const _NavGuideCarousel({
    required this.guides,
    required this.activeIdx,
    required this.route,
    required this.onPageChanged,
    required this.onClose,
  });

  final List<RouteGuide> guides;
  final int activeIdx;
  final RouteResultEntity route;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onClose;

  @override
  State<_NavGuideCarousel> createState() => _NavGuideCarouselState();
}

class _NavGuideCarouselState extends State<_NavGuideCarousel> {
  late final PageController _pc;
  int _visiblePage = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: widget.activeIdx);
    _visiblePage = widget.activeIdx;
  }

  @override
  void didUpdateWidget(_NavGuideCarousel old) {
    super.didUpdateWidget(old);
    if (old.activeIdx != widget.activeIdx && _pc.hasClients) {
      _visiblePage = widget.activeIdx;
      _pc.animateToPage(
        widget.activeIdx,
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
    final guides = widget.guides;
    if (guides.isEmpty) return const SizedBox.shrink();
    final accent = _navAccentColor(widget.route.transport);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 106,
          child: PageView.builder(
            controller: _pc,
            itemCount: guides.length,
            onPageChanged: (idx) {
              setState(() => _visiblePage = idx);
              widget.onPageChanged(idx);
            },
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _GuideStepCard(
                guide: guides[i],
                accent: accent,
                isActive: i == widget.activeIdx,
                onClose: widget.onClose,
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        // Page dots
        if (guides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < guides.length; i++)
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
      ],
    );
  }
}

// ── Single guide step card ─────────────────────────────────────────────────

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({
    required this.guide,
    required this.accent,
    required this.isActive,
    required this.onClose,
  });

  final RouteGuide guide;
  final Color accent;
  final bool isActive;
  final VoidCallback onClose;

  String get _distLabel {
    final d = guide.distanceM;
    if (d <= 0) return '';
    return d < 1000 ? '${d}m' : '${(d / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _guideIconForType(guide.type, guide.guidance);
    final label = _guideTurnText(guide.type, guide.guidance);

    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? accent.withValues(alpha: 0.6) : Colors.white12,
          width: isActive ? 1.5 : 1.0,
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
                // Direction icon + distance
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isActive ? 0.18 : 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: isActive ? 0.5 : 0.2),
                        ),
                      ),
                      child: Icon(icon, size: 28, color: accent),
                    ),
                    if (_distLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _distLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 14),
                // Turn label + guidance detail
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
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
                        guide.guidance,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kMapWhite45,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Close button (top-right)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onClose,
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

// ── Guide direction marker widget (for NMarker on map) ─────────────────────

class _GuideDirectionMarker extends StatelessWidget {
  const _GuideDirectionMarker({required this.type, required this.guidance});
  final int type;
  final String guidance;

  @override
  Widget build(BuildContext context) {
    final icon = _guideIconForType(type, guidance);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, size: 24, color: Colors.black87),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Navigation bottom strip ────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _NavBottomStrip extends StatelessWidget {
  const _NavBottomStrip({
    required this.navState,
    required this.route,
    required this.onStop,
    required this.currentGuideIdx,
    required this.totalGuides,
    required this.onPrevGuide,
    required this.onNextGuide,
  });

  final ModeANavState navState;
  final RouteResultEntity route;
  final VoidCallback onStop;
  final int currentGuideIdx;
  final int totalGuides;
  final VoidCallback onPrevGuide;
  final VoidCallback onNextGuide;

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
    final accent = _navAccentColor(route.transport);

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
                  '약 ${navState.remainingMinutes}분 · '
                  '${(route.fromName.length > 8 ? '${route.fromName.substring(0, 8)}…' : route.fromName)} → '
                  '${(route.toName.length > 8 ? '${route.toName.substring(0, 8)}…' : route.toName)}',
                  style: const TextStyle(
                      fontSize: 11, color: kMapWhite45, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const Spacer(),
            // Prev / next guide step buttons
            if (totalGuides > 1) ...[
              _GuideNavBtn(
                icon: Icons.chevron_left_rounded,
                enabled: currentGuideIdx > 0,
                onTap: onPrevGuide,
              ),
              const SizedBox(width: 2),
              Text(
                '${currentGuideIdx + 1}/$totalGuides',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: kMapWhite45),
              ),
              _GuideNavBtn(
                icon: Icons.chevron_right_rounded,
                enabled: currentGuideIdx < totalGuides - 1,
                onTap: onNextGuide,
              ),
              const SizedBox(width: 10),
            ],
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
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.redAccent),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _GuideNavBtn extends StatelessWidget {
  const _GuideNavBtn({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? kMapWhite87 : kMapWhite45,
        ),
      ),
    );
  }
}
