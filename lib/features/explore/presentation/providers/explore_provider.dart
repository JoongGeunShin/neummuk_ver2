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

// ─── State ────────────────────────────────────────────────────────────────────

class ExploreState {
  const ExploreState({
    this.query = '',
    this.category = '전체',
    this.results = const [],
    this.popularFoods = const [],
    this.isLoading = false,
    this.isSearchingApi = false,
    this.errorMessage,
  });

  final String query;
  final String category;
  final List<FoodCatalogEntity> results;
  final List<FoodCatalogEntity> popularFoods;
  final bool isLoading;
  /// 검색 버튼으로 API 호출 중일 때 true
  final bool isSearchingApi;
  final String? errorMessage;

  bool get isSearchMode => query.isNotEmpty;

  ExploreState copyWith({
    String? query,
    String? category,
    List<FoodCatalogEntity>? results,
    List<FoodCatalogEntity>? popularFoods,
    bool? isLoading,
    bool? isSearchingApi,
    String? errorMessage,
  }) =>
      ExploreState(
        query: query ?? this.query,
        category: category ?? this.category,
        results: results ?? this.results,
        popularFoods: popularFoods ?? this.popularFoods,
        isLoading: isLoading ?? this.isLoading,
        isSearchingApi: isSearchingApi ?? this.isSearchingApi,
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
    final repo = ref.read(foodCatalogRepositoryProvider);
    await repo.seedInitialData();
    await _loadPopular();
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

  void setQuery(String q) {
    state = state.copyWith(query: q, isSearchingApi: false);
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      state = state.copyWith(results: []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _quickSearch);
  }

  /// 타이핑 중 실시간 검색 — Firestore 캐시만 조회
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

  /// 검색 버튼 — Firestore + API 전체 파이프라인
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
      debugPrint('[Explore] submitSearch result: ${items.length} items');
      state = state.copyWith(results: items, isLoading: false, isSearchingApi: false);
    } catch (e) {
      debugPrint('[Explore] submitSearch error: $e');
      state = state.copyWith(isLoading: false, isSearchingApi: false);
    }
  }

  void setCategory(String cat) {
    state = state.copyWith(category: cat, results: []);
    if (state.query.isNotEmpty) {
      _quickSearch();
    } else {
      _loadPopular();
    }
  }

  Future<void> onFoodTapped(FoodCatalogEntity food) async {
    // 상세 조회 시 검색 카운트 증가
    await ref
        .read(foodCatalogRepositoryProvider)
        .incrementSearchCount(food.canonicalName);
    // 로컬 상태에도 즉시 반영
    _updateCountLocally(food.canonicalName);
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
                isSeeded: f.isSeeded,
              )
            : f)
        .toList();

    state = state.copyWith(
      popularFoods: bump(state.popularFoods),
      results: bump(state.results),
    );
  }
}
