import '../entities/place_entity.dart';

abstract class PlaceRepository {
  Future<List<PlaceEntity>> searchNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    String? keyword,
    bool isCategory = false,
  });
}
