import 'package:flutter/material.dart';
import '../utils/context_ext.dart';
import '../../features/record/domain/entities/weekly_data_entity.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.data});
  final List<WeeklyDataEntity> data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = data
        .map((d) => [d.burn, d.food].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final burnH = max > 0 ? (d.burn / max) * 110 : 0.0;
          final foodH = max > 0 ? (d.food / max) * 110 : 0.0;
          return Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Bar(height: burnH, color: c.kcalActivity),
                      const SizedBox(width: 3),
                      _Bar(height: foodH, color: c.kcalFood),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.label,
                  style: AppTypography.tiny.copyWith(
                    fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w600,
                    color: d.isToday ? c.primary : c.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      width: context.screenWidth * 0.025,
      height: height.clamp(2.0, 110.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(6),
          bottom: Radius.circular(2),
        ),
      ),
    );
  }
}
