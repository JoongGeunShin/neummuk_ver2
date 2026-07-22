import '../../../explore/domain/entities/food_catalog_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';

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
    BodyMetrics metrics = BodyMetrics.defaultMetrics,
  }) {
    final kcal = c.nutrition.caloriesKcal.round();
    final walkRatePerMin =
        AppConstants.kcalPerHour(transport: 'walk', metrics: metrics) / 60;
    final bikeRatePerMin =
        AppConstants.kcalPerHour(transport: 'bike', metrics: metrics) / 60;
    return FoodEntity(
      id: c.canonicalName,
      name: c.displayName,
      kcal: kcal,
      category: c.category,
      emoji: c.emoji,
      walkMinutes: kcal <= 0 ? 0 : (kcal / walkRatePerMin).round(),
      bikeMinutes: kcal <= 0 ? 0 : (kcal / bikeRatePerMin).round(),
    );
  }

  int minutesFor(String transport) =>
      transport == 'bike' ? bikeMinutes : walkMinutes;
}
