import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

enum FoodImageType { noodle, pork, kimbap, soup, pork2, cafe, generic }

class FoodImageWidget extends StatelessWidget {
  const FoodImageWidget({
    super.key,
    required this.type,
    this.width,
    this.height = 100,
    this.borderRadius = 0,
  });

  final FoodImageType type;
  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = switch (type) {
      FoodImageType.noodle => (const Color(0xFF3A2418), const Color(0xFFFFA869), '🍜'),
      FoodImageType.pork => (const Color(0xFF3A2014), const Color(0xFFFF8A4C), '🍱'),
      FoodImageType.kimbap => (const Color(0xFF1F2818), const Color(0xFF7CD68E), '🍙'),
      FoodImageType.soup => (const Color(0xFF2A1F14), const Color(0xFFFFC56E), '🍲'),
      FoodImageType.pork2 => (const Color(0xFF2E1810), const Color(0xFFFF5A3C), '🥓'),
      FoodImageType.cafe => (const Color(0xFF2A1F14), const Color(0xFFD6A56B), '☕'),
      FoodImageType.generic => (const Color(0xFF2A2030), c.primary, '🍽️'),
    };
    final (bg, glow, emoji) = theme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: RadialGradient(
          center: const Alignment(0.4, -0.5),
          radius: 1.2,
          colors: [glow.withValues(alpha: 0.2), bg],
        ),
        border: Border.all(color: c.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: (height * 0.5).clamp(20.0, 56.0)),
          ),
        ),
      ),
    );
  }

  static FoodImageType fromString(String s) => switch (s) {
        'noodle' => FoodImageType.noodle,
        'pork' => FoodImageType.pork,
        'kimbap' => FoodImageType.kimbap,
        'soup' => FoodImageType.soup,
        'pork2' => FoodImageType.pork2,
        'cafe' => FoodImageType.cafe,
        _ => FoodImageType.generic,
      };
}
