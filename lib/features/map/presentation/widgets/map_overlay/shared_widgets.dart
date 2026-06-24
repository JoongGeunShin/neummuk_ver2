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
          color: active ? kMapPrimary.withValues(alpha: 0.9) : Colors.transparent,
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
// ── 위치 오버레이 방향 콘 아이콘 (setBearing으로 회전됨)
// ════════════════════════════════════════════════════════════════════════════

class _LocationBearingIcon extends StatelessWidget {
  const _LocationBearingIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 80),
      painter: _LocationBeamPainter(color: context.colors.pinUser),
    );
  }
}

class _LocationBeamPainter extends CustomPainter {
  const _LocationBeamPainter({required this.color});
  final Color color;

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
        ..color = color.withValues(alpha: 0.38)
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
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LocationBeamPainter old) => old.color != color;
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
      angle: bearingDeg * (pi / 180),
      child: CustomPaint(
        size: const Size(16, 16),
        painter: _ChevronArrowPainter(color: color),
      ),
    );
  }
}

class _ChevronArrowPainter extends CustomPainter {
  const _ChevronArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 위쪽을 가리키는 쉐브론 (방향 회전은 Transform.rotate에서 처리)
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.90, h * 0.62)
      ..lineTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.10, h * 0.62)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ChevronArrowPainter old) => old.color != color;
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
        color: context.colors.pinSight,
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
