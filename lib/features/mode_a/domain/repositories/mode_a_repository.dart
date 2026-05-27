import '../entities/restaurant_entity.dart';
import '../entities/route_result_entity.dart';
import '../entities/waypoint_candidate_entity.dart';

abstract interface class ModeARepository {
  /// 출발지 → (경유지들) → 목적지 경로 계산
  /// Kakao Mobility POST /v1/waypoints/directions (도보·자전거)
  /// ODsay searchPubTransPathT (대중교통)
  Future<RouteResultEntity> getRoute({
    required String from,
    required String to,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
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

  /// 경유지 추천 후보 조회
  /// TourAPI locationBasedList2 (관광지·레포츠) + 하버사인 우회 거리 계산
  Future<List<WaypointCandidateEntity>> getWaypointCandidates({
    required double midLat,
    required double midLng,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required int extraKcalNeeded,
    required String transport,
    required double weightKg,
  });
}
