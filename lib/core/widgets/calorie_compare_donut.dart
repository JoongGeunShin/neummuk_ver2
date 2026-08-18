import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/context_ext.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

class CalorieCompareDonut extends StatelessWidget {
  const CalorieCompareDonut({
    super.key,
    required this.kcalBurn,
    required this.kcalFood,
    this.size = 180,
  });

  final int kcalBurn;
  final int kcalFood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = kcalFood - kcalBurn;
    final netLabel = net > 0 ? '+$net' : '$net';
    final netColor = net > 0 ? c.danger : c.success;
    final max = [kcalBurn, kcalFood, 100].reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              burnFrac: (kcalBurn / max).clamp(0.0, 1.0),
              foodFrac: (kcalFood / max).clamp(0.0, 1.0),
              burnColor: c.kcalActivity,
              foodColor: c.kcalFood,
              bgColor: c.surfaceHi,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NET',
                    style: AppTypography.tiny.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    netLabel,
                    style: TextStyle(
                      fontSize: size * 0.178,
                      fontWeight: FontWeight.w800,
                      color: netColor,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: AppTypography.tiny.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Legend(dot: c.kcalActivity, label: '소모', value: '$kcalBurn kcal'),
            const SizedBox(width: 18),
            _Legend(dot: c.kcalFood, label: '섭취', value: '$kcalFood kcal'),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.burnFrac,
    required this.foodFrac,
    required this.burnColor,
    required this.foodColor,
    required this.bgColor,
  });

  final double burnFrac;
  final double foodFrac;
  final Color burnColor;
  final Color foodColor;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 18.0;
    final r = (size.width - stroke) / 2;
    final innerR = r - stroke - 4;
    final innerStroke = stroke - 4;
    final center = Offset(size.width / 2, size.height / 2);
    final startAngle = -math.pi / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    final innerBgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = innerStroke
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r, bgPaint);
    canvas.drawCircle(center, innerR, innerBgPaint);

    if (foodFrac > 0) {
      final foodPaint = Paint()
        ..color = foodColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        2 * math.pi * foodFrac,
        false,
        foodPaint,
      );
    }

    if (burnFrac > 0) {
      final burnPaint = Paint()
        ..color = burnColor
        ..strokeWidth = innerStroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerR),
        startAngle,
        2 * math.pi * burnFrac,
        false,
        burnPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.burnFrac != burnFrac || old.foodFrac != foodFrac;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.dot, required this.label, required this.value});
  final Color dot;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dot,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.micro.copyWith(color: c.textMuted),
            ),
            Text(
              value,
              style: AppTypography.label.copyWith(
                color: c.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
