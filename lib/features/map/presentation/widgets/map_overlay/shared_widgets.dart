part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode toggle ───────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onExplore,
    required this.onModeA,
  });

  final MapMode mode;
  final VoidCallback onExplore;
  final VoidCallback onModeA;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleTab(
            icon: Icons.explore_rounded,
            label: '탐색',
            active: mode == MapMode.explore,
            onTap: onExplore,
          ),
          _ToggleTab(
            icon: Icons.route_rounded,
            label: '경로',
            active: mode == MapMode.modeA,
            onTap: onModeA,
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kMapGreen.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : kMapWhite45),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : kMapWhite45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Cluster helpers ───────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _Cluster {
  const _Cluster(this.center, this.places);
  final NLatLng center;
  final List<PlaceEntity> places;
}

class _ClusterDot extends StatelessWidget {
  const _ClusterDot({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF03C75A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
