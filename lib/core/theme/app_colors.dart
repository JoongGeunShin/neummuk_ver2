import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHi,
    required this.outline,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.onPrimary,
    required this.primary,
    required this.primarySoft,
    required this.primaryGlow,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.kcalActivity,
    required this.kcalFood,
    required this.success,
    required this.warn,
    required this.danger,
    required this.pinFood,
    required this.pinCafe,
    required this.pinSight,
    required this.pinUser,
    required this.mapBg,
    required this.mapRoadMinor,
    required this.mapRoadMajor,
    required this.mapRoadHighway,
    required this.mapWater,
    required this.mapPark,
    required this.cardBg,
    required this.cardText,
    required this.cardTextMuted,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceHi;
  final Color outline;
  final Color divider;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color onPrimary;
  final Color primary;
  final Color primarySoft;
  final Color primaryGlow;
  final Color secondary;
  final Color secondarySoft;
  final Color accent;
  final Color kcalActivity;
  final Color kcalFood;
  final Color success;
  final Color warn;
  final Color danger;
  final Color pinFood;
  final Color pinCafe;
  final Color pinSight;
  final Color pinUser;
  final Color mapBg;
  final Color mapRoadMinor;
  final Color mapRoadMajor;
  final Color mapRoadHighway;
  final Color mapWater;
  final Color mapPark;
  final Color cardBg;
  final Color cardText;
  final Color cardTextMuted;

  static AppColors dark() => const AppColors(
        bg: Color(0xFF15131A),
        surface: Color(0xFF1E1A22),
        surfaceAlt: Color(0xFF28232E),
        surfaceHi: Color(0xFF332C3A),
        outline: Color(0x14FFFFFF),
        divider: Color(0x0FFFFFFF),
        text: Color(0xFFF5EFE6),
        textMuted: Color(0xFFA89E94),
        textFaint: Color(0xFF736B62),
        onPrimary: Color(0xFF1A0F08),
        primary: Color(0xFFFF7A45),
        primarySoft: Color(0xFF3A1E12),
        primaryGlow: Color(0x2EFF7A45),
        secondary: Color(0xFFFF4D6D),
        secondarySoft: Color(0xFF3A1218),
        accent: Color(0xFFFFC56E),
        kcalActivity: Color(0xFFFF7A45),
        kcalFood: Color(0xFFFFC56E),
        success: Color(0xFF3DD68C),
        warn: Color(0xFFFFB547),
        danger: Color(0xFFFF5A5F),
        pinFood: Color(0xFFFF7A45),
        pinCafe: Color(0xFFFFC56E),
        pinSight: Color(0xFFFF4D6D),
        pinUser: Color(0xFF7C8AFF),
        mapBg: Color(0xFF15131A),
        mapRoadMinor: Color(0xFF2B262F),
        mapRoadMajor: Color(0xFF3A323F),
        mapRoadHighway: Color(0xFF534653),
        mapWater: Color(0xFF1B2434),
        mapPark: Color(0xFF1A2218),
        cardBg: Color(0xFFFFFFFF),
        cardText: Color(0xFF1A1620),
        cardTextMuted: Color(0xFF6A6168),
      );

  static AppColors light() => const AppColors(
        bg: Color(0xFFFFF8F2),
        surface: Color(0xFFFFFFFF),
        surfaceAlt: Color(0xFFFAF1E8),
        surfaceHi: Color(0xFFF2E6D8),
        outline: Color(0x141A1620),
        divider: Color(0x0F1A1620),
        text: Color(0xFF1A1620),
        textMuted: Color(0xFF6A6168),
        textFaint: Color(0xFFA39A91),
        onPrimary: Color(0xFFFFFFFF),
        primary: Color(0xFFFF6A33),
        primarySoft: Color(0xFFFFE5D7),
        primaryGlow: Color(0x2EFF6A33),
        secondary: Color(0xFFFF4D6D),
        secondarySoft: Color(0xFFFFE0E6),
        accent: Color(0xFFF2A23B),
        kcalActivity: Color(0xFFFF6A33),
        kcalFood: Color(0xFFF2A23B),
        success: Color(0xFF27B57A),
        warn: Color(0xFFE89730),
        danger: Color(0xFFE54F54),
        pinFood: Color(0xFFFF6A33),
        pinCafe: Color(0xFFF2A23B),
        pinSight: Color(0xFFFF4D6D),
        pinUser: Color(0xFF5B6FE0),
        mapBg: Color(0xFFEFEAE1),
        mapRoadMinor: Color(0xFFFFFFFF),
        mapRoadMajor: Color(0xFFFFFFFF),
        mapRoadHighway: Color(0xFFFFE9CC),
        mapWater: Color(0xFFC8D8E4),
        mapPark: Color(0xFFD8E6CD),
        cardBg: Color(0xFFFFFFFF),
        cardText: Color(0xFF1A1620),
        cardTextMuted: Color(0xFF6A6168),
      );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceHi,
    Color? outline,
    Color? divider,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? onPrimary,
    Color? primary,
    Color? primarySoft,
    Color? primaryGlow,
    Color? secondary,
    Color? secondarySoft,
    Color? accent,
    Color? kcalActivity,
    Color? kcalFood,
    Color? success,
    Color? warn,
    Color? danger,
    Color? pinFood,
    Color? pinCafe,
    Color? pinSight,
    Color? pinUser,
    Color? mapBg,
    Color? mapRoadMinor,
    Color? mapRoadMajor,
    Color? mapRoadHighway,
    Color? mapWater,
    Color? mapPark,
    Color? cardBg,
    Color? cardText,
    Color? cardTextMuted,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceHi: surfaceHi ?? this.surfaceHi,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      onPrimary: onPrimary ?? this.onPrimary,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryGlow: primaryGlow ?? this.primaryGlow,
      secondary: secondary ?? this.secondary,
      secondarySoft: secondarySoft ?? this.secondarySoft,
      accent: accent ?? this.accent,
      kcalActivity: kcalActivity ?? this.kcalActivity,
      kcalFood: kcalFood ?? this.kcalFood,
      success: success ?? this.success,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      pinFood: pinFood ?? this.pinFood,
      pinCafe: pinCafe ?? this.pinCafe,
      pinSight: pinSight ?? this.pinSight,
      pinUser: pinUser ?? this.pinUser,
      mapBg: mapBg ?? this.mapBg,
      mapRoadMinor: mapRoadMinor ?? this.mapRoadMinor,
      mapRoadMajor: mapRoadMajor ?? this.mapRoadMajor,
      mapRoadHighway: mapRoadHighway ?? this.mapRoadHighway,
      mapWater: mapWater ?? this.mapWater,
      mapPark: mapPark ?? this.mapPark,
      cardBg: cardBg ?? this.cardBg,
      cardText: cardText ?? this.cardText,
      cardTextMuted: cardTextMuted ?? this.cardTextMuted,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceHi: Color.lerp(surfaceHi, other.surfaceHi, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondarySoft: Color.lerp(secondarySoft, other.secondarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      kcalActivity: Color.lerp(kcalActivity, other.kcalActivity, t)!,
      kcalFood: Color.lerp(kcalFood, other.kcalFood, t)!,
      success: Color.lerp(success, other.success, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      pinFood: Color.lerp(pinFood, other.pinFood, t)!,
      pinCafe: Color.lerp(pinCafe, other.pinCafe, t)!,
      pinSight: Color.lerp(pinSight, other.pinSight, t)!,
      pinUser: Color.lerp(pinUser, other.pinUser, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      mapRoadMinor: Color.lerp(mapRoadMinor, other.mapRoadMinor, t)!,
      mapRoadMajor: Color.lerp(mapRoadMajor, other.mapRoadMajor, t)!,
      mapRoadHighway: Color.lerp(mapRoadHighway, other.mapRoadHighway, t)!,
      mapWater: Color.lerp(mapWater, other.mapWater, t)!,
      mapPark: Color.lerp(mapPark, other.mapPark, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardText: Color.lerp(cardText, other.cardText, t)!,
      cardTextMuted: Color.lerp(cardTextMuted, other.cardTextMuted, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
