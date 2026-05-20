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

  final int steps;
  final double distanceM;
  final double caloriesKcal;
  final double speedKmh;
  final Duration elapsed;
  final bool isTracking;

  /// 속도 기반 자동 감지: sedentary / walk / walk_fast / jog / run / bike / transit
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
