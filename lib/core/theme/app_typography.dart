import 'package:flutter/material.dart';

/// 앱 전역 폰트 사이즈·굵기 스케일. 실사용 중인 모든 fontSize(8~44)를 커버한다.
///
/// letterSpacing/height는 의도적으로 넣지 않는다 — `TextStyle.copyWith`는
/// 인자로 null을 넘기면 "기존 값 유지"로 처리해 null로 되돌릴 방법이 없다.
/// 여기 기본값에 height를 박아두면 원래 자연 행간(null)이던 곳까지 전부
/// 강제로 값이 생겨버리므로, letterSpacing/height/color는 항상 사용처에서
/// `.copyWith(...)`로 채운다.
class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Pretendard';

  static const TextStyle displayXl = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    fontFamily: _fontFamily,
  );
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontFamily: _fontFamily,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    fontFamily: _fontFamily,
  );
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: _fontFamily,
  );
  static const TextStyle titleSm = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFamily: _fontFamily,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontFamily: _fontFamily,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: _fontFamily,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    fontFamily: _fontFamily,
  );
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFamily: _fontFamily,
  );
  static const TextStyle bodyMute = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: _fontFamily,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: _fontFamily,
  );
  static const TextStyle tiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
  static const TextStyle nano = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
  static const TextStyle pico = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    fontFamily: _fontFamily,
  );
}
