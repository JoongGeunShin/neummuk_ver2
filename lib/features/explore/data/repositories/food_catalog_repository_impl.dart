import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../../domain/entities/food_nutrition_entity.dart';
import '../../domain/repositories/food_catalog_repository.dart';
import '../../domain/services/food_alias_service.dart';
import '../datasources/food_api_datasource.dart';
import '../datasources/food_firestore_datasource.dart';
import 'food_seed_data.dart';

class FoodCatalogRepositoryImpl implements FoodCatalogRepository {
  FoodCatalogRepositoryImpl()
      : _api = FoodApiDatasource(),
        _firestore = FoodFirestoreDatasource();

  final FoodApiDatasource _api;
  final FoodFirestoreDatasource _firestore;

  static const _seedKey = 'food_catalog_seeded_v1';

  @override
  Future<List<FoodCatalogEntity>> searchFoods(
    String query, {
    String? category,
  }) async {
    if (query.trim().isEmpty) return getPopularFoods(category: category);

    final resolved = FoodAliasService.resolve(query);

    // 1. Firestore 정확 일치 먼저
    final exact = await _firestore.getByCanonicalName(resolved);
    if (exact != null) {
      final filtered = (category == null || category == '전체' || exact.category == category)
          ? [exact]
          : <FoodCatalogEntity>[];
      return filtered;
    }

    // 2. Firestore 접두어 검색
    final prefix = await _firestore.searchByPrefix(resolved, category: category);
    if (prefix.isNotEmpty) return prefix;

    // 3. Food API 폴백
    final apiItems = await _api.search(resolved);
    if (apiItems.isEmpty) return [];

    // 4. API 결과를 Firestore에 캐싱 (search_count는 포함하지 않아 기존 값 보존)
    final entities = apiItems.map((item) => _apiItemToEntity(item)).toList();
    for (final e in entities) {
      if (category == null || category == '전체' || e.category == category) {
        final m = e.toFirestoreMap()..remove('search_count');
        await _firestore.upsert(m);
      }
    }

    return category == null || category == '전체'
        ? entities
        : entities.where((e) => e.category == category).toList();
  }

  @override
  Future<List<FoodCatalogEntity>> getPopularFoods({
    String? category,
    int limit = 20,
  }) async {
    try {
      return await _firestore.getPopular(category: category, limit: limit);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> incrementSearchCount(String canonicalName) async {
    try {
      await _firestore.incrementCount(canonicalName);
    } catch (_) {}
  }

  @override
  Future<void> seedInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seedKey) == true) return;

    final maps = foodSeedData
        .map((f) => f.toFirestoreMap()
          ..remove('updated_at')
          ..remove('search_count')) // update 규칙: search_count는 +1만 허용 → 시드에서 제외
        .toList();

    // 실패해도 재시도 방지: 실패 시 다음 앱 실행에서 자동 재시도하지 않도록 먼저 저장
    await prefs.setBool(_seedKey, true);
    try {
      await _firestore.batchUpsert(maps);
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────

  FoodCatalogEntity _apiItemToEntity(FoodApiItem item) {
    return FoodCatalogEntity(
      canonicalName: item.foodName,
      displayName: item.foodName,
      category: '기타',
      emoji: '🍽️',
      apiFoodCd: item.foodCd,
      nutrition: FoodNutritionEntity(
        servingSizeG: item.servingSizeG > 0 ? item.servingSizeG : 100,
        caloriesKcal: item.caloriesKcal,
        carbsG: item.carbsG,
        sugarG: item.sugarG,
        proteinG: item.proteinG,
        fatG: item.fatG,
        sodiumMg: item.sodiumMg,
        saturatedFatG: item.saturatedFatG,
        cholesterolMg: item.cholesterolMg,
      ),
    );
  }
}
