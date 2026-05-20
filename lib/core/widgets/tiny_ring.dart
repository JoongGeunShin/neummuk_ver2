import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

class TinyRing extends StatelessWidget {
  const TinyRing({
    super.key,
    required this.pct,
    this.size = 32,
    this.color,
    this.label,
  });

  final double pct;
  final double size;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ringColor = color ?? c.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          pct: pct.clamp(0, 100),
          color: ringColor,
          bgColor: c.surfaceHi,
        ),
        child: Center(
          child: Text(
            label ?? '${pct.round()}%',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              color: ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct, required this.color, required this.bgColor});
  final double pct;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.125;
    final r = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, bgPaint);

    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * (pct / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color;
}
