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

// ════════════════════════════════════════════════════════════════════════════
// ── Map compass widget ─────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _MapCompassWidget extends StatelessWidget {
  const _MapCompassWidget({required this.bearing, required this.onTap});
  final double bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRotated = bearing.abs() > 1.5;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kMapPanel,
          shape: BoxShape.circle,
          border: Border.all(
            color: isRotated ? Colors.white38 : Colors.white12,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Transform.rotate(
            angle: -bearing * (3.14159265359 / 180),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 12,
                  color: isRotated ? const Color(0xFFE74C3C) : kMapWhite45,
                ),
                Text(
                  'N',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isRotated ? const Color(0xFFE74C3C) : kMapWhite45,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 위치 오버레이 방향 콘 아이콘 (setBearing으로 회전됨)
// ════════════════════════════════════════════════════════════════════════════

class _LocationBearingIcon extends StatelessWidget {
  const _LocationBearingIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 80),
      painter: const _LocationBeamPainter(),
    );
  }
}

class _LocationBeamPainter extends CustomPainter {
  const _LocationBeamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 10.0;

    // 방향 콘: 위쪽으로 펼쳐지는 부채꼴 (Bearing 방향)
    final beamPath = Path()
      ..moveTo(cx, cy - r - 1)
      ..lineTo(cx - 16, 4)
      ..lineTo(cx + 16, 4)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..color = const Color(0xFF4285F4).withValues(alpha: 0.38)
        ..style = PaintingStyle.fill,
    );

    // 흰 테두리 원
    canvas.drawCircle(
      Offset(cx, cy),
      r + 2.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 파란 채움 원
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ════════════════════════════════════════════════════════════════════════════
// ── 경로 방향 화살표 아이콘 (베어링 각도가 이미 구워진 static 이미지)
// ════════════════════════════════════════════════════════════════════════════

class _RouteArrowIcon extends StatelessWidget {
  const _RouteArrowIcon({required this.bearingDeg, required this.color});
  final double bearingDeg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: bearingDeg * (3.14159265359 / 180),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
        ),
        child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.white),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Cluster helpers ─────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

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
