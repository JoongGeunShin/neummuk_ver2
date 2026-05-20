import '../entities/restaurant_entity.dart';
import '../entities/route_result_entity.dart';

abstract interface class ModeARepository {
  /// 출발지 → (경유지들) → 목적지 경로 계산
  /// Kakao Mobility POST /v1/waypoints/directions 호출
  Future<RouteResultEntity> getRoute({
    required String from,
    required String to,
    required String transport,
    required double weightKg,
    List<RouteWaypoint> waypoints,
  });

  /// 출발지에서 여러 목적지까지 거리/시간 일괄 조회
  /// Kakao Mobility POST /v1/destinations/directions 호출
  Future<List<RouteResultEntity>> getRoutesToDestinations({
    required double fromLat,
    required double fromLng,
    required List<RouteWaypoint> destinations,
    required String transport,
    required double weightKg,
  });

  Future<List<RestaurantEntity>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
  });
}
