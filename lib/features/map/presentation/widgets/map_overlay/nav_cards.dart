part of '../map_overlay.dart';

// ── Guide type helpers ───────────────────────────────────────────────────────

Color _navAccentColor(String transport, BuildContext context) {
  final c = context.colors;
  return switch (transport) {
    'bike' => c.warn,
    'transit' => c.pinUser,
    _ => kMapPrimary,
  };
}

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
    final accent = _navAccentColor(widget.route.transport, context);

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

