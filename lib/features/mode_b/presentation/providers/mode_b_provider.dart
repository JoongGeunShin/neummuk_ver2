import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../explore/presentation/providers/explore_provider.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../data/repositories/mode_b_repository_impl.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';

part 'mode_b_provider.g.dart';

const _pageSize = 5;

@Riverpod(keepAlive: true)
ModeBRepository modeBRepository(ModeBRepositoryRef ref) {
  final foodCatalog = ref.watch(foodCatalogRepositoryProvider);
  final weightKg = ref.watch(userProfileProvider).valueOrNull?.weightKg
      ?? AppConstants.defaultWeightKg;
  return ModeBRepositoryImpl(
    foodCatalogRepo: foodCatalog,
    weightKg: weightKg,
  );
}

// ─── Food search ──────────────────────────────────────────────
class FoodSearchState {
  const FoodSearchState({
    this.query = '',
    this.category = '전체',
    this.foods = const [],
    this.isLoading = false,
  });

  final String query;
  final String category;
  final List<FoodEntity> foods;
  final bool isLoading;

  FoodSearchState copyWith({
    String? query,
    String? category,
    List<FoodEntity>? foods,
    bool? isLoading,
  }) {
    return FoodSearchState(
      query: query ?? this.query,
      category: category ?? this.category,
      foods: foods ?? this.foods,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class FoodSearch extends _$FoodSearch {
  @override
  FoodSearchState build() {
    Future.microtask(loadFoods);
    return const FoodSearchState();
  }

  Future<void> loadFoods() async {
    state = state.copyWith(isLoading: true);
    final foods = await ref.read(modeBRepositoryProvider).getFoods(
          query: state.query.isEmpty ? null : state.query,
          category: state.category,
        );
    state = state.copyWith(foods: foods, isLoading: false);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    loadFoods();
  }

  void setCategory(String cat) {
    state = state.copyWith(category: cat);
    loadFoods();
  }
}

// ─── Selected food ────────────────────────────────────────────
@Riverpod(keepAlive: true)
class SelectedFood extends _$SelectedFood {
  @override
  FoodEntity? build() => null;

  void set(FoodEntity? food) => state = food;
}

// ─── Route search ─────────────────────────────────────────────
class RouteSearchState {
  const RouteSearchState({
    this.transport = 'walk',
    this.selectedRouteIdx = 0,
    this.allRoutes = const [],
    this.displayedRoutes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isStarted = false,
  });

  final String transport;
  final int selectedRouteIdx;

  /// 전체 정렬된 코스 목록 (백그라운드 보관)
  final List<TouristRouteEntity> allRoutes;

  /// 현재 화면에 표시 중인 코스 목록 (5개씩 증가)
  final List<TouristRouteEntity> displayedRoutes;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isStarted;

  /// 더 보기 가능 여부
  bool get hasMore => displayedRoutes.length < allRoutes.length;

  /// 기존 코드 호환용
  List<TouristRouteEntity> get routes => displayedRoutes;

  TouristRouteEntity? get selectedRoute => displayedRoutes.isEmpty
      ? null
      : displayedRoutes[selectedRouteIdx.clamp(0, displayedRoutes.length - 1)];

  RouteSearchState copyWith({
    String? transport,
    int? selectedRouteIdx,
    List<TouristRouteEntity>? allRoutes,
    List<TouristRouteEntity>? displayedRoutes,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isStarted,
  }) {
    return RouteSearchState(
      transport: transport ?? this.transport,
      selectedRouteIdx: selectedRouteIdx ?? this.selectedRouteIdx,
      allRoutes: allRoutes ?? this.allRoutes,
      displayedRoutes: displayedRoutes ?? this.displayedRoutes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isStarted: isStarted ?? this.isStarted,
    );
  }
}

@riverpod
class RouteSearch extends _$RouteSearch {
  @override
  RouteSearchState build() => const RouteSearchState();

  Future<void> loadRoutes(
    FoodEntity food, {
    double lat = 37.5635,
    double lng = 126.9869,
  }) async {
    state = state.copyWith(
      isLoading: true,
      selectedRouteIdx: 0,
      allRoutes: [],
      displayedRoutes: [],
      isStarted: false,
    );

    final all = await ref.read(modeBRepositoryProvider).getTouristRoutes(
          latitude: lat,
          longitude: lng,
          targetKcal: food.kcal,
          transport: state.transport,
        );

    if (all.isEmpty) {
      state = state.copyWith(allRoutes: [], displayedRoutes: [], isLoading: false);
      return;
    }

    // 첫 5개 표시 후 즉시 enrichment
    final firstBatch = all.take(_pageSize).toList();
    state = state.copyWith(
      allRoutes: all,
      displayedRoutes: firstBatch,
      isLoading: false,
    );

    // 첫 번째 배치 enrichment (백그라운드)
    _enrichAndUpdate(startIdx: 0, batch: firstBatch);
  }

  /// "더 보기" — 다음 5개 로드 + enrichment
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final nextStart = state.displayedRoutes.length;
    final nextBatch = state.allRoutes.skip(nextStart).take(_pageSize).toList();

    // 바로 목록에 추가 (기본 정보로 먼저 표시)
    state = state.copyWith(
      displayedRoutes: [...state.displayedRoutes, ...nextBatch],
      isLoadingMore: false,
    );

    // enrichment (백그라운드, 완료되면 해당 아이템만 갱신)
    _enrichAndUpdate(startIdx: nextStart, batch: nextBatch);
  }

  /// batch를 enrichment하고 displayedRoutes에서 해당 위치 업데이트
  Future<void> _enrichAndUpdate({
    required int startIdx,
    required List<TouristRouteEntity> batch,
  }) async {
    final enriched = await ref.read(modeBRepositoryProvider).enrichBatch(batch);

    // state가 리셋됐거나 범위 초과 시 무시
    if (state.displayedRoutes.length < startIdx + enriched.length) return;

    final updated = [...state.displayedRoutes];
    for (var i = 0; i < enriched.length; i++) {
      updated[startIdx + i] = enriched[i];
    }
    state = state.copyWith(displayedRoutes: updated);
  }

  void setTransport(String t, FoodEntity food,
      {double lat = 37.5635, double lng = 126.9869}) {
    state = state.copyWith(transport: t, selectedRouteIdx: 0);
    loadRoutes(food, lat: lat, lng: lng);
  }

  void selectRoute(int idx) =>
      state = state.copyWith(selectedRouteIdx: idx, isStarted: false);

  void startRoute() => state = state.copyWith(isStarted: true);

  void reset() => state = const RouteSearchState();
}
