import '../../../mode_a/domain/entities/restaurant_entity.dart';

abstract interface class ModeMatchRepository {
  /// food_catalog(Firestore)에서 targetKcal ±20% 이내이면서 [preferredCategories]에
  /// 속하는 음식을 찾아 Kakao Local(FD6) 키워드검색으로 실제 매장을 매칭한다.
  /// [preferredCategories]가 비어있으면 카테고리 무관, kcal 조건만 적용한다.
  Future<List<RestaurantEntity>> getMatchedRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
    required List<String> preferredCategories,
  });
}
