class WalkSessionEntity {
  const WalkSessionEntity({
    this.steps = 0,
    this.distanceM = 0.0,
    this.caloriesKcal = 0.0,
    this.speedKmh = 0.0,
    this.elapsed = Duration.zero,
    this.isTracking = false,
    this.activityType = 'sedentary',
    this.trackingEnabled = true,
  });
  final int steps;
  final double distanceM;
  final double caloriesKcal;
  final double speedKmh;
  /// 앱을 켠 시점부터의 경과 시간. 표시 전용이며 칼로리 계산에는 쓰이지 않는다.
  final Duration elapsed;
  /// 페도미터 센서 구독이 활성화되어 있으면 true.
  /// activityRecognition 권한이 없거나 센서 미지원 기기면 false.
  final bool isTracking;
  final String activityType;
  /// 사용자가 개인 설정에서 백그라운드 추적(Foreground Service)을 켜 두었는지 여부.
  /// false면 서비스가 아예 시작되지 않아 배터리를 소모하지 않는다.
  final bool trackingEnabled;
  WalkSessionEntity copyWith({
    int? steps,
    double? distanceM,
    double? caloriesKcal,
    double? speedKmh,
    Duration? elapsed,
    bool? isTracking,
    String? activityType,
    bool? trackingEnabled,
  }) =>
      WalkSessionEntity(
        steps: steps ?? this.steps,
        distanceM: distanceM ?? this.distanceM,
        caloriesKcal: caloriesKcal ?? this.caloriesKcal,
        speedKmh: speedKmh ?? this.speedKmh,
        elapsed: elapsed ?? this.elapsed,
        isTracking: isTracking ?? this.isTracking,
        activityType: activityType ?? this.activityType,
        trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      );
}
