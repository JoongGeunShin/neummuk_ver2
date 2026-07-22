import '../../../../core/models/body_metrics.dart';
import '../../../map/domain/entities/place_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
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
    required BodyMetrics metrics,
    List<RouteWaypoint> waypoints,
  });

  Future<List<RestaurantEntity>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
  });

  /// 도착지 근처 TourAPI 장소 조회 (관광지·문화시설·축제·여행코스)
  Future<List<PlaceEntity>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int contentTypeId,
  });

  /// 도착지 근처 두루누비 코스 조회 (위치 기반 필터링)
  Future<List<TouristRouteEntity>> getNearbyDurunubiCourses({
    required double latitude,
    required double longitude,
    required BodyMetrics metrics,
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
    required BodyMetrics metrics,
  });
}
