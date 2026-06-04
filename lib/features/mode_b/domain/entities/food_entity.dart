import '../../../explore/domain/entities/food_catalog_entity.dart';
import '../../../../core/constants/app_constants.dart';

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

  factory FoodEntity.fromCatalog(
    FoodCatalogEntity c, {
    double weightKg = AppConstants.defaultWeightKg,
  }) {
    final kcal = c.nutrition.caloriesKcal.round();
    final walkMet = AppConstants.metValues['walk']!;
    final bikeMet = AppConstants.metValues['bike']!;
    return FoodEntity(
      id: c.canonicalName,
      name: c.displayName,
      kcal: kcal,
      category: c.category,
      emoji: c.emoji,
      walkMinutes: kcal <= 0 ? 0 : (kcal / (walkMet * weightKg / 60)).round(),
      bikeMinutes: kcal <= 0 ? 0 : (kcal / (bikeMet * weightKg / 60)).round(),
    );
  }

  int minutesFor(String transport) =>
      transport == 'bike' ? bikeMinutes : walkMinutes;
}
