import '../entities/food_catalog_entity.dart';

abstract class FoodCatalogRepository {
  /// Firestore 캐시만 조회 (타이핑 실시간 검색용).
  Future<List<FoodCatalogEntity>> quickSearchFoods(String query, {String? category});

  /// Firestore만 조회 (검색 버튼 — 저장 없음).
  Future<List<FoodCatalogEntity>> searchFoods(String query, {String? category});

  /// 식품안전처 API에서만 조회 — 저장 없음 (사용자 수동 추가 전 후보 목록).
  Future<List<FoodCatalogEntity>> fetchCandidatesFromApi(String query);

  /// 사용자가 선택한 FoodCatalogEntity를 Firestore에 저장.
  Future<void> persistFood(FoodCatalogEntity entity);

  Future<List<FoodCatalogEntity>> getPopularFoods({String? category, int limit = 20});
  Future<void> incrementSearchCount(String canonicalName);

  /// search_count 저조 + 오래된 항목 삭제.
  Future<void> pruneStaleData();

  /// Firestore의 카테고리 목록 조회.
  Future<List<String>> getCategories();

  /// targetKcal ±tolerancePct 이내 음식을 kcal 오차 오름차순으로 반환.
  /// 매칭 0건이면 빈 리스트(호출부가 폴백 처리).
  Future<List<FoodCatalogEntity>> getFoodsNearKcal(double targetKcal, double tolerancePct);
}
