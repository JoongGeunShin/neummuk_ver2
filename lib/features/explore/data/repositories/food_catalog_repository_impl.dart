import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../../domain/entities/food_nutrition_entity.dart';
import '../../domain/repositories/food_catalog_repository.dart';
import '../../domain/services/food_emoji_service.dart';
import '../datasources/food_api_datasource.dart';
import '../datasources/food_firestore_datasource.dart';

const _pruneSearchCountThreshold = 1;
const _pruneDaysOld = 30;

/// 앱 최초 실행 시 API로 채울 인기 음식 이름 목록.
const _seedFoodNames = [
  '프라이드치킨', '양념치킨', '삼겹살', '된장찌개', '비빔밥',
  '불고기', '라면', '떡볶이', '김치찌개', '피자',
  '햄버거', '짜장면', '초밥', '돈까스', '갈비탕',
  '냉면', '족발', '보쌈', '삼계탕', '제육볶음',
];

/// 기본 제공 카테고리 (Firestore food_categories 컬렉션 초기값).
const _builtinCategories = [
  '전체', '치킨', '족발·보쌈', '돈까스·회·일식', '피자',
  '구이·고기', '야식', '양식', '중식', '아시안',
  '백반·죽·국수', '도시락', '분식', '카페·디저트', '패스트푸드',
];

class FoodCatalogRepositoryImpl implements FoodCatalogRepository {
  FoodCatalogRepositoryImpl()
      : _api = FoodApiDatasource(),
        _firestore = FoodFirestoreDatasource();

  final FoodApiDatasource _api;
  final FoodFirestoreDatasource _firestore;

  static const _seedKey = 'food_catalog_seeded_v2';
  static const _catSeedKey = 'food_categories_seeded_v1';

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

    // 1. Firestore 정확 일치
    final exact = await _firestore.getByCanonicalName(q.replaceAll(' ', ''));
    if (exact != null) {
      return (category == null || category == '전체' || exact.category == category)
          ? [exact]
          : [];
    }

    // 2. Firestore 접두어 검색
    final prefix = await _firestore.searchByPrefix(q, category: category);
    if (prefix.isNotEmpty) return prefix;

    // Firestore에 없으면 빈 목록 반환 — 자동 저장 없음
    // 사용자가 직접 "새로 추가하기"로 fetchCandidatesFromApi 호출
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
    return relevant
        .map(_apiItemToEntity)
        .where((e) => seen.add(e.canonicalName))
        .toList();
  }

  @override
  Future<void> persistFood(FoodCatalogEntity entity) async {
    try {
      // 카테고리가 기본 목록에 없으면 Firestore에 새 카테고리 생성
      if (entity.category != '기타' &&
          !_builtinCategories.contains(entity.category)) {
        await _firestore.ensureCategory(entity.category);
      }
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
  Future<void> seedInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seedKey) == true) return;

    debugPrint('[FoodRepo] API 기반 초기 시드 시작 (${_seedFoodNames.length}개)');
    await prefs.setBool(_seedKey, true);

    // 카테고리 시드
    await _seedCategories(prefs);

    const batchSize = 5;
    for (var i = 0; i < _seedFoodNames.length; i += batchSize) {
      final chunk = _seedFoodNames.sublist(i, min(i + batchSize, _seedFoodNames.length));
      await Future.wait(chunk.map(_seedOne));
    }
    debugPrint('[FoodRepo] 초기 시드 완료');
  }

  Future<void> _seedCategories(SharedPreferences prefs) async {
    if (prefs.getBool(_catSeedKey) == true) return;
    await prefs.setBool(_catSeedKey, true);
    try {
      final cats = _builtinCategories
          .asMap()
          .entries
          .map((e) => {
                'name': e.value,
                'order': e.key,
                'is_builtin': true,
              })
          .toList();
      await _firestore.seedCategories(cats);
      debugPrint('[FoodRepo] 카테고리 시드 완료');
    } catch (e) {
      debugPrint('[FoodRepo] 카테고리 시드 실패: $e');
    }
  }

  Future<void> _seedOne(String foodName) async {
    try {
      final items = await _api.search(foodName, numOfRows: 1);
      if (items.isEmpty) return;
      // 시드는 가장 관련성 높은 항목 우선 — _isRelevant 통과하는 첫 번째 항목
      final relevant = items.firstWhere(
        (it) => _isRelevant(it.foodName, foodName),
        orElse: () => items.first,
      );
      final entity = _apiItemToEntity(relevant);
      final m = entity.toFirestoreMap()..remove('search_count');
      await _firestore.upsert(m);
      await _firestore.incrementCount(entity.canonicalName);
      debugPrint('[FoodRepo] seeded: ${entity.displayName} (${entity.nutrition.caloriesKcal.round()} kcal)');
    } catch (e) {
      debugPrint('[FoodRepo] seed failed for $foodName: $e');
    }
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
      if (cats.isEmpty) return _builtinCategories;
      // '전체'는 항상 맨 앞에
      final sorted = [
        if (!cats.contains('전체')) '전체',
        ...cats.where((c) => c != '전체'),
      ];
      return sorted;
    } catch (_) {
      return _builtinCategories;
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

    // 대분류와 검색어가 서로 다른 음식 카테고리면 제외
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
    // 대분류_음식명 구조면 음식명만 displayName으로
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

    // 카테고리: 매핑 없으면 API cat2 → cat1 순으로 원본 카테고리명 사용
    String category = FoodEmojiService.resolveCategory(
      foodName: displayName,
      cat1: item.foodCat1Name,
      cat2: item.foodCat2Name,
    );
    if (category == '기타') {
      if (item.foodCat2Name.isNotEmpty) {
        category = item.foodCat2Name;
      } else if (item.foodCat1Name.isNotEmpty) {
        category = item.foodCat1Name;
      }
    }

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
