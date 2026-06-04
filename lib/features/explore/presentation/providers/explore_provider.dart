import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/food_catalog_repository_impl.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../../domain/repositories/food_catalog_repository.dart';

part 'explore_provider.g.dart';

@Riverpod(keepAlive: true)
FoodCatalogRepository foodCatalogRepository(FoodCatalogRepositoryRef ref) =>
    FoodCatalogRepositoryImpl();

// savingCanonicalName에 null을 명시적으로 set하기 위한 sentinel
const _sentinel = Object();

// ─── State ────────────────────────────────────────────────────────────────────

class ExploreState {
  const ExploreState({
    this.query = '',
    this.category = '전체',
    this.results = const [],
    this.popularFoods = const [],
    this.isLoading = false,
    this.isSearchingApi = false,
    this.apiCandidates = const [],
    this.isLoadingCandidates = false,
    this.savingCanonicalName,
    this.categories = const [],
    this.errorMessage,
  });

  final String query;
  final String category;
  final List<FoodCatalogEntity> results;
  final List<FoodCatalogEntity> popularFoods;
  final bool isLoading;
  /// 검색 버튼으로 API 조회 중
  final bool isSearchingApi;
  /// "새로 추가하기" API 후보 목록
  final List<FoodCatalogEntity> apiCandidates;
  /// API 후보 로딩 중
  final bool isLoadingCandidates;
  /// 저장 중인 항목 canonicalName (null이면 저장 중 아님)
  final String? savingCanonicalName;
  /// Firestore에서 로드한 카테고리 목록
  final List<String> categories;
  final String? errorMessage;

  bool get isSearchMode => query.isNotEmpty;
  bool get isSaving => savingCanonicalName != null;

  ExploreState copyWith({
    String? query,
    String? category,
    List<FoodCatalogEntity>? results,
    List<FoodCatalogEntity>? popularFoods,
    bool? isLoading,
    bool? isSearchingApi,
    List<FoodCatalogEntity>? apiCandidates,
    bool? isLoadingCandidates,
    Object? savingCanonicalName = _sentinel,
    List<String>? categories,
    String? errorMessage,
  }) =>
      ExploreState(
        query: query ?? this.query,
        category: category ?? this.category,
        results: results ?? this.results,
        popularFoods: popularFoods ?? this.popularFoods,
        isLoading: isLoading ?? this.isLoading,
        isSearchingApi: isSearchingApi ?? this.isSearchingApi,
        apiCandidates: apiCandidates ?? this.apiCandidates,
        isLoadingCandidates: isLoadingCandidates ?? this.isLoadingCandidates,
        savingCanonicalName: savingCanonicalName == _sentinel
            ? this.savingCanonicalName
            : savingCanonicalName as String?,
        categories: categories ?? this.categories,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

@riverpod
class Explore extends _$Explore {
  Timer? _debounce;

  @override
  ExploreState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(_init);
    return const ExploreState();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadPopular(),
      _loadCategories(),
      _pruneStale(),
    ]);
  }

  Future<void> _loadPopular() async {
    state = state.copyWith(isLoading: true);
    try {
      final pop = await ref
          .read(foodCatalogRepositoryProvider)
          .getPopularFoods(
            category: state.category == '전체' ? null : state.category,
          );
      state = state.copyWith(popularFoods: pop, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats =
          await ref.read(foodCatalogRepositoryProvider).getCategories();
      state = state.copyWith(categories: cats);
    } catch (_) {}
  }

  Future<void> _pruneStale() async {
    try {
      await ref.read(foodCatalogRepositoryProvider).pruneStaleData();
    } catch (_) {}
  }

  void setQuery(String q) {
    state = state.copyWith(
      query: q,
      isSearchingApi: false,
      apiCandidates: [],
    );
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      state = state.copyWith(results: []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _quickSearch);
  }

  Future<void> _quickSearch() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await ref
          .read(foodCatalogRepositoryProvider)
          .quickSearchFoods(
            state.query,
            category: state.category == '전체' ? null : state.category,
          );
      state = state.copyWith(results: items, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 검색 버튼 — Firestore만 조회 (자동 저장 없음)
  Future<void> submitSearch() async {
    if (state.query.trim().isEmpty) return;
    _debounce?.cancel();
    debugPrint('[Explore] submitSearch: "${state.query}"');
    state = state.copyWith(isSearchingApi: true, isLoading: true);
    try {
      final items = await ref
          .read(foodCatalogRepositoryProvider)
          .searchFoods(
            state.query,
            category: state.category == '전체' ? null : state.category,
          );
      state = state.copyWith(
        results: items,
        isLoading: false,
        isSearchingApi: false,
      );
    } catch (e) {
      debugPrint('[Explore] submitSearch error: $e');
      state = state.copyWith(isLoading: false, isSearchingApi: false);
    }
  }

  /// "새로 추가하기" — API 후보 목록 조회
  Future<void> fetchApiCandidates(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(isLoadingCandidates: true, apiCandidates: []);
    try {
      final candidates = await ref
          .read(foodCatalogRepositoryProvider)
          .fetchCandidatesFromApi(query);
      state = state.copyWith(
        apiCandidates: candidates,
        isLoadingCandidates: false,
      );
    } catch (e) {
      debugPrint('[Explore] fetchApiCandidates error: $e');
      state = state.copyWith(isLoadingCandidates: false);
    }
  }

  /// 사용자가 선택한 항목을 Firestore에 저장 (저장 중 gesture 차단)
  Future<bool> saveSelectedFood(FoodCatalogEntity entity) async {
    if (state.isSaving) return false; // 중복 호출 방지
    state = state.copyWith(savingCanonicalName: entity.canonicalName);
    try {
      await ref.read(foodCatalogRepositoryProvider).persistFood(entity);
      await Future.wait([
        _quickSearch(),
        _loadCategories(),
      ]);
      state = state.copyWith(
        apiCandidates: [],
        savingCanonicalName: null,
      );
      return true;
    } catch (e) {
      debugPrint('[Explore] saveSelectedFood error: $e');
      state = state.copyWith(savingCanonicalName: null);
      return false;
    }
  }

  void setCategory(String cat) {
    state = state.copyWith(category: cat, results: [], apiCandidates: []);
    if (state.query.isNotEmpty) {
      _quickSearch();
    } else {
      _loadPopular();
    }
  }

  Future<void> onFoodTapped(FoodCatalogEntity food) async {
    await ref
        .read(foodCatalogRepositoryProvider)
        .incrementSearchCount(food.canonicalName);
    _updateCountLocally(food.canonicalName);
  }

  void clearApiCandidates() {
    state = state.copyWith(apiCandidates: []);
  }

  void _updateCountLocally(String canonicalName) {
    List<FoodCatalogEntity> bump(List<FoodCatalogEntity> list) => list
        .map((f) => f.canonicalName == canonicalName
            ? FoodCatalogEntity(
                canonicalName: f.canonicalName,
                displayName: f.displayName,
                category: f.category,
                emoji: f.emoji,
                nutrition: f.nutrition,
                tags: f.tags,
                searchCount: f.searchCount + 1,
                apiFoodCd: f.apiFoodCd,
              )
            : f)
        .toList();

    state = state.copyWith(
      popularFoods: bump(state.popularFoods),
      results: bump(state.results),
    );
  }
}
