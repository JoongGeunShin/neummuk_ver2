import '../entities/food_entity.dart';
import '../entities/spot_entity.dart';
import '../entities/tourist_route_entity.dart';

abstract interface class ModeBRepository {
  Future<List<FoodEntity>> getFoods({String? query, String? category});

  /// 기성 코스 검색 (두루누비 + TourAPI 여행코스 contentTypeId=25)
  /// [radiusM]: 걷기 3000m / 자전거 5000m
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
    int radiusM = 3000,
  });

  Future<List<TouristRouteEntity>> enrichBatch(List<TouristRouteEntity> batch);

  /// 스팟 검색: 카카오 로컬 > TourAPI 개별 장소 순 우선순위
  Future<List<SpotEntity>> searchSpots({
    required double latitude,
    required double longitude,
    required Set<SpotTag> tags,
    required String transport,
  });

  /// 스팟 목록 → 코스 생성
  /// [mandatorySpots] 반드시 포함할 스팟 (카트 기반) — TSP 순서로 먼저 배치, spots 풀로 보충
  /// [forceAll]       true = spots 전부 포함 + TSP 순서
  TouristRouteEntity? generateCourse({
    required List<SpotEntity> spots,
    required double userLat,
    required double userLng,
    required int targetKcal,
    required String transport,
    List<SpotEntity> mandatorySpots = const [],
    bool forceAll = false,
  });
}
