import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/mode_b_repository_impl.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';

part 'mode_b_provider.g.dart';

// keepAlive: 탭 이동 후에도 상태 유지
@Riverpod(keepAlive: true)
ModeBRepository modeBRepository(ModeBRepositoryRef ref) => ModeBRepositoryImpl();

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

// class FoodSearch → generates foodSearchProvider
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
// keepAlive: 화면 전환 중 autoDispose로 null 초기화되는 것 방지
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
    this.routes = const [],
    this.isLoading = false,
  });

  final String transport;
  final int selectedRouteIdx;
  final List<TouristRouteEntity> routes;
  final bool isLoading;

  TouristRouteEntity? get selectedRoute =>
      routes.isEmpty ? null : routes[selectedRouteIdx.clamp(0, routes.length - 1)];

  RouteSearchState copyWith({
    String? transport,
    int? selectedRouteIdx,
    List<TouristRouteEntity>? routes,
    bool? isLoading,
  }) {
    return RouteSearchState(
      transport: transport ?? this.transport,
      selectedRouteIdx: selectedRouteIdx ?? this.selectedRouteIdx,
      routes: routes ?? this.routes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// class RouteSearch → generates routeSearchProvider
@riverpod
class RouteSearch extends _$RouteSearch {
  @override
  RouteSearchState build() => const RouteSearchState();

  Future<void> loadRoutes(
    FoodEntity food, {
    double lat = 37.5635,
    double lng = 126.9869,
  }) async {
    state = state.copyWith(isLoading: true, selectedRouteIdx: 0);
    final routes = await ref.read(modeBRepositoryProvider).getTouristRoutes(
          latitude: lat,
          longitude: lng,
          targetKcal: food.kcal,
          transport: state.transport,
        );
    state = state.copyWith(routes: routes, isLoading: false);
  }

  void setTransport(String t, FoodEntity food, {double lat = 37.5635, double lng = 126.9869}) {
    state = state.copyWith(transport: t, selectedRouteIdx: 0);
    loadRoutes(food, lat: lat, lng: lng);
  }

  void selectRoute(int idx) => state = state.copyWith(selectedRouteIdx: idx);
}
