class WeeklyDataEntity {
  const WeeklyDataEntity({
    required this.label,
    required this.burn,
    required this.food,
    this.isToday = false,
  });

  final String label;
  final int burn;
  final int food;
  final bool isToday;
}
