/// MOVEMENT_CONVENTION 기반 칼로리·속도·보폭 계산
///
/// MET 구간 (속도 → MET 선형 보간):
///   0.0 ~ 1.0  km/h → sedentary  MET 1.0
///   1.0 ~ 6.5  km/h → 걷기       MET 2.5 → 4.8
///   6.5 ~ 15.0 km/h → 조깅·달리기 MET 6.0 → 10.0
///  15.0 ~ 25.0 km/h → 자전거     MET 6.0 → 8.0
///  25.0+       km/h → 대중교통   MET 1.5
class WalkCalculator {
  WalkCalculator._();

  // ── 보폭 ─────────────────────────────────────────────────
  /// 키(cm) + 성별 → 보폭(m).  남 ×0.415, 여 ×0.413 (cm→m 변환 포함)
  static double strideM(double heightCm, String sex) =>
      heightCm * (sex == 'female' ? 0.413 : 0.415) / 100.0;

  static double distanceM(int steps, double strideM) => steps * strideM;

  // ── MET 계산 ──────────────────────────────────────────────
  static double met(double speedKmh) {
    if (speedKmh < 1.0) return 1.0;
    if (speedKmh < 6.5) return _lerp(speedKmh, 1.0, 6.5, 2.5, 4.8);
    if (speedKmh < 15.0) return _lerp(speedKmh, 6.5, 15.0, 6.0, 10.0);
    if (speedKmh < 25.0) return _lerp(speedKmh, 15.0, 25.0, 6.0, 8.0);
    return 1.5;
  }

  /// 속도 기반 이동수단 자동 감지
  static String activityType(double speedKmh) {
    if (speedKmh < 1.0) return 'sedentary';
    if (speedKmh < 4.5) return 'walk';
    if (speedKmh < 6.5) return 'walk_fast';
    if (speedKmh < 10.0) return 'jog';
    if (speedKmh < 15.0) return 'run';
    if (speedKmh < 25.0) return 'bike';
    return 'transit';
  }

  // ── 칼로리 ────────────────────────────────────────────────
  /// kcal = MET × 체중(kg) × 시간(h)
  static double caloriesKcal(double met, double weightKg, Duration elapsed) =>
      met * weightKg * elapsed.inSeconds / 3600.0;

  // ── 속도 (30초 슬라이딩 윈도우) ──────────────────────────
  /// window: (시각, 누적 이동거리m) 리스트 → 평균 속도(km/h)
  static double speedFromWindow(List<(DateTime, double)> window) {
    if (window.length < 2) return 0.0;
    final distM = window.last.$2 - window.first.$2;
    final secs =
        window.last.$1.difference(window.first.$1).inMilliseconds / 1000.0;
    if (secs <= 0.0) return 0.0;
    return (distM / secs) * 3.6;
  }

  static double _lerp(
          double x, double x0, double x1, double y0, double y1) =>
      y0 + (y1 - y0) * (x - x0) / (x1 - x0);
}
