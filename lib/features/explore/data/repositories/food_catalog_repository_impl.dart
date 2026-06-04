import 'package:flutter/foundation.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../../domain/entities/food_nutrition_entity.dart';
import '../../domain/repositories/food_catalog_repository.dart';
import '../../domain/services/food_emoji_service.dart';
import '../datasources/food_api_datasource.dart';
import '../datasources/food_firestore_datasource.dart';

const _pruneSearchCountThreshold = 1;
const _pruneDaysOld = 30;

class FoodCatalogRepositoryImpl implements FoodCatalogRepository {
  FoodCatalogRepositoryImpl()
      : _api = FoodApiDatasource(),
        _firestore = FoodFirestoreDatasource();

  final FoodApiDatasource _api;
  final FoodFirestoreDatasource _firestore;

  @override
  Future<List<FoodCatalogEntity>> quickSearchFoods(
    String query, {
    String? category,
  }) async {
    if (query.trim().isEmpty) return getPopularFoods(category: category);

    final q = query.trim();
    final exact = await _firestore.getByCanonicalName(q.replaceAll(' ', ''));
    if (exact != null) {
      return (category == null || category == '전체' || exact.category == category)
          ? [exact]
          : [];
    }
    return _firestore.searchByPrefix(q, category: category);
  }

  @override
  Future<List<FoodCatalogEntity>> searchFoods(
    String query, {
    String? category,
  }) async {
    if (query.trim().isEmpty) return getPopularFoods(category: category);

    final q = query.trim();

    final exact = await _firestore.getByCanonicalName(q.replaceAll(' ', ''));
    if (exact != null) {
      return (category == null || category == '전체' || exact.category == category)
          ? [exact]
          : [];
    }

    final prefix = await _firestore.searchByPrefix(q, category: category);
    if (prefix.isNotEmpty) return prefix;

    debugPrint('[FoodRepo] searchFoods: Firestore miss for "$q", returning empty');
    return [];
  }

  @override
  Future<List<FoodCatalogEntity>> fetchCandidatesFromApi(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();

    debugPrint('[FoodRepo] fetchCandidatesFromApi: "$q"');
    final apiItems = await _api.search(q, numOfRows: 20);
    if (apiItems.isEmpty) {
      debugPrint('[FoodRepo] API returned no results for "$q"');
      return [];
    }

    final relevant = apiItems.where((item) => _isRelevant(item.foodName, q)).toList();
    debugPrint('[FoodRepo] API: ${apiItems.length} total → ${relevant.length} relevant');

    final seen = <String>{};
    final entities = relevant
        .map(_apiItemToEntity)
        .where((e) => seen.add(e.canonicalName))
        .toList();

    final qLower = q.toLowerCase();
    final matched = entities.where((e) {
      final dn = e.displayName.toLowerCase();
      return dn == qLower ||
          dn.startsWith('$qLower ') ||
          dn.startsWith('$qLower(') ||
          dn.startsWith('$qLower,') ||
          dn.startsWith('$qLower-');
    }).toList();

    debugPrint('[FoodRepo] after exact-match filter: ${matched.length} items');
    return matched;
  }

  @override
  Future<void> persistFood(FoodCatalogEntity entity) async {
    try {
      await _firestore.ensureCategory(entity.category);
      final m = entity.toFirestoreMap()..remove('search_count');
      await _firestore.upsert(m);
      await _firestore.incrementCount(entity.canonicalName);
      debugPrint('[FoodRepo] persisted: ${entity.displayName}');
    } catch (e) {
      debugPrint('[FoodRepo] persistFood error: $e');
      rethrow;
    }
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
  Future<void> pruneStaleData() async {
    final before = DateTime.now().subtract(const Duration(days: _pruneDaysOld));
    final deleted = await _firestore.pruneStale(
      maxCount: _pruneSearchCountThreshold,
      before: before,
    );
    debugPrint('[FoodRepo] pruneStaleData: deleted $deleted items');
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final cats = await _firestore.getCategories();
      if (cats.contains('전체')) return cats;
      return ['전체', ...cats];
    } catch (_) {
      return ['전체'];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  static bool _isRelevant(String rawFoodName, String query) {
    if (query.isEmpty) return true;
    final parts = rawFoodName.split('_');
    if (parts.length <= 1) return rawFoodName.contains(query);

    final categoryPart = parts.first;
    final foodPart = parts.sublist(1).join('_');

    if (categoryPart.contains(query) || query.contains(categoryPart)) {
      return foodPart.contains(query);
    }

    final prefixCat = FoodEmojiService.categoryFromName(categoryPart);
    final queryCat = FoodEmojiService.categoryFromName(query);
    if (prefixCat != '기타' && queryCat != '기타' && prefixCat != queryCat) {
      return false;
    }

    return foodPart.startsWith(query);
  }

  FoodCatalogEntity _apiItemToEntity(FoodApiItem item) {
    final rawName = item.foodName;
    final canonicalName = rawName.replaceAll(' ', '');
    final nameParts = rawName.split('_');
    final displayName = (nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : nameParts[0])
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final emoji = FoodEmojiService.resolveEmoji(
      foodName: displayName,
      cat1: item.foodCat1Name,
      cat2: item.foodCat2Name,
    );

    // API 원본 카테고리를 그대로 사용: FOOD_CAT2_NM → FOOD_CAT1_NM → '기타'
    // "해당없음"은 API의 null 플레이스홀더이므로 무효 처리
    bool validCat(String s) => s.isNotEmpty && s != '해당없음';
    final category = validCat(item.foodCat2Name)
        ? item.foodCat2Name
        : (validCat(item.foodCat1Name) ? item.foodCat1Name : '기타');

    return FoodCatalogEntity(
      canonicalName: canonicalName,
      displayName: displayName,
      category: category,
      emoji: emoji,
      tags: [if (item.dbClassName.isNotEmpty) item.dbClassName],
      apiFoodCd: item.foodCd,
      nutrition: FoodNutritionEntity(
        servingSizeG: item.servingSizeG > 0 ? item.servingSizeG : 100,
        caloriesKcal: item.caloriesKcal,
        carbsG: item.carbsG,
        sugarG: item.sugarG,
        proteinG: item.proteinG,
        fatG: item.fatG,
        sodiumMg: item.sodiumMg,
        saturatedFatG: item.saturatedFatG > 0 ? item.saturatedFatG : null,
        cholesterolMg: item.cholesterolMg > 0 ? item.cholesterolMg : null,
      ),
    );
  }
}
