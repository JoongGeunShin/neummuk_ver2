import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

class CalorieBar extends StatelessWidget {
  const CalorieBar({
    super.key,
    required this.kcalBurn,
    required this.kcalFood,
    this.barHeight = 8,
  });

  final int kcalBurn;
  final int kcalFood;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final max = [kcalBurn, kcalFood, 100].reduce((a, b) => a > b ? a : b);
    final burnPct = kcalBurn / max;
    final foodPct = kcalFood / max;
    return Column(
      children: [
        _BarRow(label: '🔥 소모', value: kcalBurn, pct: burnPct, height: barHeight),
        const SizedBox(height: 12),
        _BarRow(label: '🍽️ 섭취', value: kcalFood, pct: foodPct, height: barHeight),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.pct,
    required this.height,
  });

  final String label;
  final int value;
  final double pct;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = label.contains('소모') ? c.kcalActivity : c.kcalFood;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: c.text)),
            Text('$value kcal',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: c.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              Container(height: height, color: c.surfaceHi),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                widthFactor: pct,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
