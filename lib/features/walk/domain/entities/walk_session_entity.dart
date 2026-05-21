/// 현재 워크 세션의 스냅샷. UI가 ref.watch 로 수신하는 불변 데이터.
class WalkSessionEntity {
  const WalkSessionEntity({
    this.steps = 0,
    this.distanceM = 0.0,
    this.caloriesKcal = 0.0,
    this.speedKmh = 0.0,
    this.elapsed = Duration.zero,
    this.isTracking = false,
    this.activityType = 'sedentary',
  });

  /// UI에 표시되는 걸음 수.
  /// 센서에서 배치로 오는 걸음을 200ms 간격으로 1씩 드립해서 보여주므로
  /// 실제 센서값(provider 내 _trueSteps)과 일시적으로 다를 수 있다.
  final int steps;

  /// 오늘 이동한 총 거리(미터).
  /// _trueSteps × 보폭(m)으로 계산. 고정 보폭이라 ±10~20% 오차 있음.
  final double distanceM;

  /// 오늘 소모한 운동 칼로리(kcal).
  /// 속도 ≥ 1.0 km/h인 구간에서만 MET × 체중 × 시간(h)으로 1초마다 누적.
  /// 정지 구간(신호등, 휴식 등)은 포함하지 않는다.
  final double caloriesKcal;

  /// 최근 30초 슬라이딩 윈도우 기반 평균 이동 속도(km/h).
  /// 이동수단 자동 감지와 MET 계산에 사용된다.
  final double speedKmh;

  /// 앱을 켠 시점부터의 경과 시간. 표시 전용이며 칼로리 계산에는 쓰이지 않는다.
  final Duration elapsed;

  /// 페도미터 센서 구독이 활성화되어 있으면 true.
  /// activityRecognition 권한이 없거나 센서 미지원 기기면 false.
  final bool isTracking;

  /// 속도 기반 자동 감지된 이동수단.
  /// sedentary / walk / walk_fast / jog / run / bike / transit
  final String activityType;

  WalkSessionEntity copyWith({
    int? steps,
    double? distanceM,
    double? caloriesKcal,
    double? speedKmh,
    Duration? elapsed,
    bool? isTracking,
    String? activityType,
  }) =>
      WalkSessionEntity(
        steps: steps ?? this.steps,
        distanceM: distanceM ?? this.distanceM,
        caloriesKcal: caloriesKcal ?? this.caloriesKcal,
        speedKmh: speedKmh ?? this.speedKmh,
        elapsed: elapsed ?? this.elapsed,
        isTracking: isTracking ?? this.isTracking,
        activityType: activityType ?? this.activityType,
      );
}
