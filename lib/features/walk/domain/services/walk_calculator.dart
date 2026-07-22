import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';

/// MOVEMENT_CONVENTION 기반 칼로리·속도·보폭 계산
class WalkCalculator {
  WalkCalculator._();

  // ── 보폭 ─────────────────────────────────────────────────

  /// 키(cm)와 성별로 한 걸음의 보폭(m)을 추정한다.
  /// 공식: 보폭 = 키(cm) × 계수 / 100
  ///   남성 계수 0.415, 여성 계수 0.413 (MOVEMENT_CONVENTION 기준)
  /// 실제 보폭은 속도·경사도에 따라 달라지지만 여기선 고정값으로 단순화.
  static double strideM(double heightCm, String sex) =>
      heightCm * (sex == 'female' ? 0.413 : 0.415) / 100.0;

  /// 걸음 수 × 보폭(m) → 이동 거리(m)
  static double distanceM(int steps, double strideM) => steps * strideM;

  // ── MET 계산 ──────────────────────────────────────────────

  /// 속도(km/h)를 MET(운동 강도 지수)로 변환한다.
  /// 구간 경계에서 선형 보간해 부드럽게 전환.
  ///
  ///   속도(km/h)   MET 범위
  ///   0.0 ~ 1.0  → 1.0        (정지/매우 느린 이동)
  ///   1.0 ~ 6.5  → 2.5 ~ 4.8 (보통 걷기)
  ///   6.5 ~ 15.0 → 6.0 ~ 10.0 (조깅·달리기)
  ///   15.0 ~ 25.0 → 6.0 ~ 8.0 (자전거)
  ///   25.0+      → 1.5        (대중교통 — 본인이 움직이는 게 아님)
  static double met(double speedKmh) {
    if (speedKmh < 1.0) return 1.0;
    if (speedKmh < 6.5) return _lerp(speedKmh, 1.0, 6.5, 2.5, 4.8);
    if (speedKmh < 15.0) return _lerp(speedKmh, 6.5, 15.0, 6.0, 10.0);
    if (speedKmh < 25.0) return _lerp(speedKmh, 15.0, 25.0, 6.0, 8.0);
    return 1.5;
  }

  /// 속도(km/h)로 이동수단을 자동 감지해 문자열로 반환한다.
  /// WalkSessionEntity.activityType 필드에 저장되며 UI 아이콘·라벨에 사용.
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

  /// MET × (BMR/24) × 경과 시간(h) → 소모 칼로리(kcal)
  /// provider에서는 1초 단위로 증분 호출하지 않고, 이 공식을 직접 쓰지 않는다.
  /// (provider는 _elapsedTicker에서 MET × (BMR/24) / 3600 을 1초마다 직접 더함)
  static double caloriesKcal(double met, BodyMetrics metrics, Duration elapsed) =>
      met * (AppConstants.calculateBmr(metrics) / 24.0) * elapsed.inSeconds / 3600.0;

  // ── 속도 (30초 슬라이딩 윈도우) ──────────────────────────

  /// (시각, 누적 이동거리m) 쌍의 리스트를 받아 평균 속도(km/h)를 계산한다.
  /// 리스트는 최근 30초 범위만 유지되며, 가장 오래된 포인트 ~ 가장 최근 포인트
  /// 사이의 거리 차 / 시간 차로 평균 속도를 구한다.
  /// 포인트가 1개 이하거나 시간 차가 0이면 0.0 반환.
  static double speedFromWindow(List<(DateTime, double)> window) {
    if (window.length < 2) return 0.0;
    final distM = window.last.$2 - window.first.$2;
    final secs =
        window.last.$1.difference(window.first.$1).inMilliseconds / 1000.0;
    if (secs <= 0.0) return 0.0;
    return (distM / secs) * 3.6;
  }

  /// x를 [x0, x1] 구간에서 [y0, y1] 범위로 선형 보간
  static double _lerp(
          double x, double x0, double x1, double y0, double y1) =>
      y0 + (y1 - y0) * (x - x0) / (x1 - x0);
}
