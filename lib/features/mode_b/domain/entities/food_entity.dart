class FoodEntity {
  const FoodEntity({
    required this.id,
    required this.name,
    required this.kcal,
    required this.category,
    required this.emoji,
    required this.walkMinutes,
    required this.bikeMinutes,
  });

  final String id;
  final String name;
  final int kcal;
  final String category;
  final String emoji;
  final int walkMinutes;
  final int bikeMinutes;

  int minutesFor(String transport) =>
      transport == 'bike' ? bikeMinutes : walkMinutes;
}
