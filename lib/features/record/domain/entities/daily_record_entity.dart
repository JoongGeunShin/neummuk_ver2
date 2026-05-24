class DailyRecordEntity {
  const DailyRecordEntity({
    required this.date,
    required this.steps,
    required this.distanceM,
    required this.caloriesKcal,
  });

  /// YYYY-MM-DD
  final String date;
  final int steps;
  final double distanceM;
  final double caloriesKcal;

  double get distanceKm => distanceM / 1000;
}
