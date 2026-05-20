import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';
import '../../../../core/constants/app_constants.dart';

// Mock data matching the UI reference — public so RestaurantDetailScreen can look up by id
const mockRestaurants = [
  RestaurantEntity(
    id: 'r1', name: '명동교자', menu: '칼국수', category: '한식',
    kcal: 520, distanceM: 120, walkMinutes: 2, rating: 4.6, reviewCount: 1284,
    latitude: 37.5636, longitude: 126.9869,
    kind: 'food', tags: ['관광객 픽', '단품'], imageType: 'noodle',
  ),
  RestaurantEntity(
    id: 'r2', name: '남산돈까스', menu: '왕돈까스', category: '경양식',
    kcal: 720, distanceM: 230, walkMinutes: 3, rating: 4.4, reviewCount: 882,
    latitude: 37.5640, longitude: 126.9875,
    kind: 'food', tags: ['든든', '리뷰 多'], imageType: 'pork',
  ),
  RestaurantEntity(
    id: 'r3', name: '회현참치김밥', menu: '참치김밥', category: '분식',
    kcal: 380, distanceM: 180, walkMinutes: 2, rating: 4.3, reviewCount: 421,
    latitude: 37.5630, longitude: 126.9860,
    kind: 'food', tags: ['가성비'], imageType: 'kimbap',
  ),
  RestaurantEntity(
    id: 'r4', name: '후암수제비', menu: '얼큰수제비', category: '한식',
    kcal: 460, distanceM: 310, walkMinutes: 4, rating: 4.5, reviewCount: 612,
    latitude: 37.5620, longitude: 126.9880,
    kind: 'food', tags: ['뜨끈'], imageType: 'soup',
  ),
  RestaurantEntity(
    id: 'r5', name: '남산 흑돼지', menu: '삼겹살(1인분)', category: '한식',
    kcal: 620, distanceM: 420, walkMinutes: 5, rating: 4.7, reviewCount: 1903,
    latitude: 37.5645, longitude: 126.9890,
    kind: 'food', tags: ['관광지', '저녁'], imageType: 'pork2',
  ),
  RestaurantEntity(
    id: 'r6', name: '더모스트커피', menu: '라떼+크로플', category: '카페',
    kcal: 410, distanceM: 150, walkMinutes: 2, rating: 4.5, reviewCount: 538,
    latitude: 37.5632, longitude: 126.9865,
    kind: 'cafe', tags: ['뷰맛집'], imageType: 'cafe',
  ),
];

// TODO: Replace mock with Kakao Mobility API via Cloud Functions
//   - getRoute       → POST /v1/waypoints/directions  (KakaoAK REST key)
//   - getRoutesToDestinations → POST /v1/destinations/directions
//   - getNearbyRestaurants → Firestore geo-query (geoflutterfire_plus)
class ModeARepositoryImpl implements ModeARepository {
  @override
  Future<RouteResultEntity> getRoute({
    required String from,
    required String to,
    required String transport,
    required double weightKg,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // 경유지 추가 시 거리/시간이 늘어나는 mock 처리
    final extraSec = waypoints.length * 600; // 경유지당 +10분
    final extraKm = waypoints.length * 0.8;
    final durationSec = 2520 + extraSec;
    final distanceKm = 3.2 + extraKm;

    final kcalBurn = AppConstants.calculateKcal(
      transport: transport,
      weightKg: weightKg,
      durationSeconds: durationSec,
    ).round();

    return RouteResultEntity(
      fromName: from,
      toName: to,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      transport: transport,
      kcalBurn: kcalBurn,
      waypoints: waypoints,
    );
  }

  @override
  Future<List<RouteResultEntity>> getRoutesToDestinations({
    required double fromLat,
    required double fromLng,
    required List<RouteWaypoint> destinations,
    required String transport,
    required double weightKg,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    int i = 0;
    return destinations.map((dest) {
      i++;
      final durationSec = 1200 + i * 300;
      final distanceKm = 1.0 + i * 0.5;
      final kcalBurn = AppConstants.calculateKcal(
        transport: transport,
        weightKg: weightKg,
        durationSeconds: durationSec,
      ).round();
      return RouteResultEntity(
        fromName: '현재 위치',
        toName: dest.name,
        distanceKm: distanceKm,
        durationSeconds: durationSec,
        transport: transport,
        kcalBurn: kcalBurn,
      );
    }).toList();
  }

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return mockRestaurants.where((r) {
      final ratio = r.kcal / targetKcal;
      return ratio >= (1 - AppConstants.kcalMatchTolerancePct) &&
          ratio <= (1 + AppConstants.kcalMatchTolerancePct * 2);
    }).toList();
  }
}
