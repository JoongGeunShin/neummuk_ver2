import '../entities/food_catalog_entity.dart';

abstract class FoodCatalogRepository {
  Future<List<FoodCatalogEntity>> searchFoods(String query, {String? category});
  Future<List<FoodCatalogEntity>> getPopularFoods({String? category, int limit = 20});
  Future<void> incrementSearchCount(String canonicalName);
  Future<void> seedInitialData();
}
