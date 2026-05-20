import '../../domain/entities/food_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';

const _mockFoods = [
  FoodEntity(id:'f1', name:'삼겹살', kcal:620, category:'한식', emoji:'🥓', walkMinutes:89, bikeMinutes:47),
  FoodEntity(id:'f2', name:'평양냉면', kcal:480, category:'한식', emoji:'🍜', walkMinutes:69, bikeMinutes:36),
  FoodEntity(id:'f3', name:'비빔밥', kcal:580, category:'한식', emoji:'🍱', walkMinutes:83, bikeMinutes:44),
  FoodEntity(id:'f4', name:'떡볶이', kcal:420, category:'분식', emoji:'🌶️', walkMinutes:60, bikeMinutes:32),
  FoodEntity(id:'f5', name:'치킨 한마리', kcal:1200, category:'한식', emoji:'🍗', walkMinutes:172, bikeMinutes:90),
  FoodEntity(id:'f6', name:'김밥', kcal:320, category:'분식', emoji:'🍙', walkMinutes:46, bikeMinutes:24),
  FoodEntity(id:'f7', name:'짜장면', kcal:700, category:'중식', emoji:'🍜', walkMinutes:100, bikeMinutes:53),
  FoodEntity(id:'f8', name:'칼국수', kcal:520, category:'한식', emoji:'🍲', walkMinutes:74, bikeMinutes:39),
  FoodEntity(id:'f9', name:'돈까스', kcal:720, category:'경양식', emoji:'🍱', walkMinutes:103, bikeMinutes:54),
  FoodEntity(id:'f10', name:'아메리카노', kcal:10, category:'카페', emoji:'☕', walkMinutes:1, bikeMinutes:1),
  FoodEntity(id:'f11', name:'크로플', kcal:380, category:'디저트', emoji:'🧇', walkMinutes:54, bikeMinutes:29),
  FoodEntity(id:'f12', name:'김치찌개', kcal:450, category:'한식', emoji:'🍲', walkMinutes:64, bikeMinutes:34),
];

const mockRoutes = [
  TouristRouteEntity(id:'t1', name:'남산 둘레길 코스', distanceKm:4.2, durationMinutes:55, kcal:308, type:'도보', tags:['🌳 숲길', '뷰맛집']),
  TouristRouteEntity(id:'t2', name:'청계천 산책 루트', distanceKm:3.6, durationMinutes:48, kcal:268, type:'도보', tags:['💧 도심하천']),
  TouristRouteEntity(id:'t3', name:'북촌 한옥마을 코스', distanceKm:2.8, durationMinutes:38, kcal:212, type:'도보', tags:['🏯 전통']),
  TouristRouteEntity(id:'t4', name:'한강공원 자전거', distanceKm:8.5, durationMinutes:30, kcal:240, type:'자전거', tags:['🚲 야경']),
];

// TODO: Replace with Firestore foods collection + TourAPI tourist routes
class ModeBRepositoryImpl implements ModeBRepository {
  @override
  Future<List<FoodEntity>> getFoods({String? query, String? category}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockFoods.where((f) {
      if (category != null && category != '전체' && f.category != category) return false;
      if (query != null && query.isNotEmpty && !f.name.contains(query)) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final type = transport == 'bike' ? '자전거' : '도보';
    return mockRoutes.where((r) => r.type == type).toList();
  }
}
