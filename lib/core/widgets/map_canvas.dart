import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/context_ext.dart';

enum MarkerKind { food, cafe, sight, start, end }

class MapMarkerData {
  const MapMarkerData({
    required this.x,
    required this.y,
    required this.kind,
    this.label,
  });
  final double x;
  final double y;
  final MarkerKind kind;
  final String? label;
}

class RouteData {
  const RouteData({required this.points, required this.color});
  final List<Offset> points;
  final Color color;
}

class MapCanvas extends StatelessWidget {
  const MapCanvas({
    super.key,
    this.route,
    this.markers = const [],
    this.userPosition,
    this.scale = 1.0,
    this.translateX = 0.0,
    this.translateY = 0.0,
  });

  final RouteData? route;
  final List<MapMarkerData> markers;
  final Offset? userPosition;
  final double scale;
  final double translateX;
  final double translateY;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned.fill(
      child: ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..translate(translateX, translateY)
            ..scale(scale),
          alignment: Alignment.center,
          child: Stack(
            children: [
              // SVG-style map background
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapPainter(colors: c),
                ),
              ),
              // Route polyline
              if (route != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoutePainter(route: route!),
                  ),
                ),
              // Markers
              ...markers.map((m) => _buildMarker(context, m, c)),
              // User position
              if (userPosition != null)
                _buildUserDot(context, userPosition!, c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(BuildContext ctx, MapMarkerData m, AppColors c) {
    final screenW = MediaQuery.sizeOf(ctx).width;
    final screenH = MediaQuery.sizeOf(ctx).height;
    const mapW = 800.0, mapH = 1200.0;
    final px = (m.x / mapW) * screenW;
    final py = (m.y / mapH) * screenH;
    final color = switch (m.kind) {
      MarkerKind.food => c.pinFood,
      MarkerKind.cafe => c.pinCafe,
      MarkerKind.sight => c.pinSight,
      MarkerKind.start => c.primary,
      MarkerKind.end => c.secondary,
    };
    final glyph = switch (m.kind) {
      MarkerKind.food => 'F',
      MarkerKind.cafe => 'C',
      MarkerKind.sight => 'S',
      MarkerKind.start => 'A',
      MarkerKind.end => 'B',
    };

    return Positioned(
      left: px - 16,
      top: py - 16,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: c.bg, width: 2),
        ),
        child: Center(
          child: Text(
            glyph,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDot(BuildContext ctx, Offset pos, AppColors c) {
    final screenW = MediaQuery.sizeOf(ctx).width;
    final screenH = MediaQuery.sizeOf(ctx).height;
    const mapW = 800.0, mapH = 1200.0;
    final px = (pos.dx / mapW) * screenW;
    final py = (pos.dy / mapH) * screenH;

    return Positioned(
      left: px - 9,
      top: py - 9,
      child: _PulseDotWidget(color: c.pinUser, size: 18),
    );
  }
}

class _PulseDotWidget extends StatefulWidget {
  const _PulseDotWidget({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  State<_PulseDotWidget> createState() => _PulseDotWidgetState();
}

class _PulseDotWidgetState extends State<_PulseDotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this)
      ..repeat();
    _scale = Tween(begin: 1.0, end: 2.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.4 * (1 - _ctrl.value)),
                ),
                width: widget.size,
                height: widget.size,
              ),
            ),
          ),
          Container(
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              border: const Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map background painter ───
class _MapPainter extends CustomPainter {
  _MapPainter({required this.colors});
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = colors.mapBg);

    final sx = size.width / 800;
    final sy = size.height / 1200;

    // Park
    final parkPaint = Paint()
      ..color = colors.mapPark.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final parkPath = Path()
      ..moveTo(620 * sx, 60 * sy)
      ..lineTo(880 * sx, 60 * sy)
      ..lineTo(880 * sx, 240 * sy)
      ..cubicTo(820 * sx, 250 * sy, 740 * sx, 240 * sy, 700 * sx, 230 * sy)
      ..cubicTo(660 * sx, 215 * sy, 640 * sx, 180 * sy, 620 * sx, 140 * sy)
      ..close();
    canvas.drawPath(parkPath, parkPaint);

    // River
    final riverPaint = Paint()
      ..color = colors.mapWater
      ..style = PaintingStyle.fill;
    final riverPath = Path()
      ..moveTo(-40 * sx, 1100 * sy)
      ..cubicTo(120 * sx, 1080 * sy, 280 * sx, 1140 * sy, 420 * sx, 1100 * sy)
      ..cubicTo(560 * sx, 1060 * sy, 700 * sx, 1060 * sy, 900 * sx, 1090 * sy)
      ..lineTo(900 * sx, 1240 * sy)
      ..lineTo(-40 * sx, 1240 * sy)
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    // Minor roads
    final minorPaint = Paint()
      ..color = colors.mapRoadMinor
      ..strokeWidth = 4 * math.min(sx, sy)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawRoad(canvas, 'M 60 -20 L 80 1240', sx, sy, minorPaint);
    _drawRoad(canvas, 'M -40 300 L 900 280', sx, sy, minorPaint);
    _drawRoad(canvas, 'M -40 700 L 800 720', sx, sy, minorPaint);
    _drawRoad(canvas, 'M -40 850 L 880 870', sx, sy, minorPaint);
    _drawRoad(canvas, 'M 380 -20 L 360 540 L 380 1240', sx, sy, minorPaint);

    // Major roads
    final majorPaint = Paint()
      ..color = colors.mapRoadMajor
      ..strokeWidth = 9 * math.min(sx, sy)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawRoad(canvas, 'M -40 540 L 420 540 L 880 530', sx, sy, majorPaint);
    _drawRoad(canvas, 'M -20 200 L 480 380 L 880 600', sx, sy, majorPaint);
    _drawRoad(canvas, 'M 540 -20 L 540 600 L 540 1240', sx, sy, majorPaint);
  }

  void _drawRoad(Canvas canvas, String d, double sx, double sy, Paint paint) {
    final parts = d.trim().split(RegExp(r'\s+'));
    final path = Path();
    double cx = 0, cy = 0;
    int i = 0;
    while (i < parts.length) {
      switch (parts[i]) {
        case 'M':
          cx = double.parse(parts[i + 1]) * sx;
          cy = double.parse(parts[i + 2]) * sy;
          path.moveTo(cx, cy);
          i += 3;
        case 'L':
          cx = double.parse(parts[i + 1]) * sx;
          cy = double.parse(parts[i + 2]) * sy;
          path.lineTo(cx, cy);
          i += 3;
        case 'C':
          final x1 = double.parse(parts[i + 1]) * sx;
          final y1 = double.parse(parts[i + 2]) * sy;
          final x2 = double.parse(parts[i + 3]) * sx;
          final y2 = double.parse(parts[i + 4]) * sy;
          final x = double.parse(parts[i + 5]) * sx;
          final y = double.parse(parts[i + 6]) * sy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          cx = x;
          cy = y;
          i += 7;
        default:
          i++;
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.colors != colors;
}

// ─── Route painter ───
class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.route});
  final RouteData route;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.points.isEmpty) return;
    const mapW = 800.0, mapH = 1200.0;

    final pts = route.points.map((p) => Offset(
          (p.dx / mapW) * size.width,
          (p.dy / mapH) * size.height,
        )).toList();

    final glowPaint = Paint()
      ..color = route.color.withValues(alpha: 0.18)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final mainPaint = Paint()
      ..color = route.color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route;
}
