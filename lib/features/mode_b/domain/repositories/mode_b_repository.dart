import '../entities/food_entity.dart';
import '../entities/tourist_route_entity.dart';

abstract interface class ModeBRepository {
  Future<List<FoodEntity>> getFoods({String? query, String? category});
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
  });
}
