import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

extension ContextSizeExt on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// width percentage: wp(4) = 4% of screen width
  double wp(double pct) => screenWidth * pct / 100;

  /// height percentage: hp(6) = 6% of screen height
  double hp(double pct) => screenHeight * pct / 100;

  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// 하단 시스템 내비게이션 바 높이 (edge-to-edge 모드에서 콘텐츠 여백 계산용)
  double get bottomPadding => MediaQuery.viewPaddingOf(this).bottom;
}
