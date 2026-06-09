import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../explore/presentation/providers/explore_provider.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../data/repositories/mode_b_repository_impl.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';

part 'mode_b_provider.g.dart';

const _pageSize = 5;

@Riverpod(keepAlive: true)
ModeBRepository modeBRepository(ModeBRepositoryRef ref) {
  final foodCatalog = ref.watch(foodCatalogRepositoryProvider);
  final weightKg =
      ref.watch(userProfileProvider).valueOrNull?.weightKg ?? AppConstants.defaultWeightKg;
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
  }) =>
      FoodSearchState(
        query: query ?? this.query,
        category: category ?? this.category,
        foods: foods ?? this.foods,
        isLoading: isLoading ?? this.isLoading,
      );
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
    this.selectedTags = const {},
    this.selectedRouteIdx = -1,
    this.allRoutes = const [],
    this.displayedRoutes = const [],
    this.generatedCourse,
    this.generatedCourseSelected = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isFetchingSpots = false,
    this.navPending = false,
  });

  final String transport;

  /// 선택된 스팟 태그 (비어있으면 전체 선택)
  final Set<SpotTag> selectedTags;

  final int selectedRouteIdx;
  final List<TouristRouteEntity> allRoutes;
  final List<TouristRouteEntity> displayedRoutes;

  /// 스팟 조합으로 생성된 코스 (null = 아직 생성 안 함)
  final TouristRouteEntity? generatedCourse;

  /// 생성 코스가 선택된 상태 (기성 코스 선택과 배타적)
  final bool generatedCourseSelected;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isFetchingSpots;

  /// place_detail_screen에서 "안내 시작"을 눌렀을 때 true → map_overlay에서 nav 시작
  final bool navPending;

  bool get hasMore => displayedRoutes.length < allRoutes.length;
  List<TouristRouteEntity> get routes => displayedRoutes;

  TouristRouteEntity? get selectedRoute {
    if (generatedCourseSelected) return generatedCourse;
    if (displayedRoutes.isEmpty || selectedRouteIdx < 0) return null;
    final idx = selectedRouteIdx.clamp(0, displayedRoutes.length - 1);
    return displayedRoutes[idx];
  }

  /// 반경 (걷기 3km / 자전거 5km)
  int get radiusM => transport == 'bike' ? 5000 : 3000;

  RouteSearchState copyWith({
    String? transport,
    Set<SpotTag>? selectedTags,
    int? selectedRouteIdx,
    List<TouristRouteEntity>? allRoutes,
    List<TouristRouteEntity>? displayedRoutes,
    Object? generatedCourse = _kKeep,
    bool? generatedCourseSelected,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isFetchingSpots,
    bool? navPending,
  }) =>
      RouteSearchState(
        transport: transport ?? this.transport,
        selectedTags: selectedTags ?? this.selectedTags,
        selectedRouteIdx: selectedRouteIdx ?? this.selectedRouteIdx,
        allRoutes: allRoutes ?? this.allRoutes,
        displayedRoutes: displayedRoutes ?? this.displayedRoutes,
        generatedCourse: identical(generatedCourse, _kKeep)
            ? this.generatedCourse
            : generatedCourse as TouristRouteEntity?,
        generatedCourseSelected: generatedCourseSelected ?? this.generatedCourseSelected,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isFetchingSpots: isFetchingSpots ?? this.isFetchingSpots,
        navPending: navPending ?? this.navPending,
      );
}

const _kKeep = Object();

@riverpod
class RouteSearch extends _$RouteSearch {
  @override
  RouteSearchState build() => const RouteSearchState();

  // ── 기성 코스 로드 (두루누비 + TourAPI 여행코스) ─────────────────────

  Future<void> loadRoutes(
    FoodEntity food, {
    double lat = 37.5635,
    double lng = 126.9869,
  }) async {
    state = state.copyWith(
      isLoading: true,
      selectedRouteIdx: -1,
      allRoutes: [],
      displayedRoutes: [],
      generatedCourse: null,
      generatedCourseSelected: false,
    );

    final all = await ref.read(modeBRepositoryProvider).getTouristRoutes(
          latitude: lat,
          longitude: lng,
          targetKcal: food.kcal,
          transport: state.transport,
          radiusM: state.radiusM,
        );

    if (all.isEmpty) {
      state = state.copyWith(allRoutes: [], displayedRoutes: [], isLoading: false);
      return;
    }

    final firstBatch = all.take(_pageSize).toList();
    state = state.copyWith(
      allRoutes: all,
      displayedRoutes: firstBatch,
      isLoading: false,
    );

    _enrichAndUpdate(startIdx: 0, batch: firstBatch);
  }

  // ── 스팟 검색 + 코스 생성 ─────────────────────────────────────────

  Future<void> generateCourseFromSpots(
    FoodEntity food, {
    double lat = 37.5635,
    double lng = 126.9869,
  }) async {
    state = state.copyWith(isFetchingSpots: true, generatedCourse: null);

    try {
      final spots = await ref.read(modeBRepositoryProvider).searchSpots(
            latitude: lat,
            longitude: lng,
            tags: state.selectedTags,
            transport: state.transport,
          );

      if (spots.isEmpty) {
        state = state.copyWith(isFetchingSpots: false);
        return;
      }

      final course = ref.read(modeBRepositoryProvider).generateCourse(
            spots: spots,
            userLat: lat,
            userLng: lng,
            targetKcal: food.kcal,
            transport: state.transport,
          );

      state = state.copyWith(
        generatedCourse: course,
        isFetchingSpots: false,
      );
    } catch (_) {
      state = state.copyWith(isFetchingSpots: false);
    }
  }

  // ── 태그 토글 ──────────────────────────────────────────────────────

  void toggleTag(SpotTag tag) {
    final current = Set<SpotTag>.from(state.selectedTags);
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }
    state = state.copyWith(selectedTags: current);
  }

  void selectAllTags() => state = state.copyWith(selectedTags: const {});

  // ── 더 보기 ────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final nextStart = state.displayedRoutes.length;
    final nextBatch = state.allRoutes.skip(nextStart).take(_pageSize).toList();

    state = state.copyWith(
      displayedRoutes: [...state.displayedRoutes, ...nextBatch],
      isLoadingMore: false,
    );

    _enrichAndUpdate(startIdx: nextStart, batch: nextBatch);
  }

  Future<void> _enrichAndUpdate({
    required int startIdx,
    required List<TouristRouteEntity> batch,
  }) async {
    final enriched = await ref.read(modeBRepositoryProvider).enrichBatch(batch);
    if (state.displayedRoutes.length < startIdx + enriched.length) return;

    final updated = [...state.displayedRoutes];
    for (var i = 0; i < enriched.length; i++) {
      updated[startIdx + i] = enriched[i];
    }
    state = state.copyWith(displayedRoutes: updated);
  }

  // ── Transport ─────────────────────────────────────────────────────

  void setTransport(String t, FoodEntity food,
      {double lat = 37.5635, double lng = 126.9869}) {
    state = state.copyWith(transport: t, selectedRouteIdx: 0);
    loadRoutes(food, lat: lat, lng: lng);
  }

  // ── 루트 선택 / 시작 ───────────────────────────────────────────────

  void selectRoute(int idx) => state = state.copyWith(
        selectedRouteIdx: idx,
        generatedCourseSelected: false,
      );

  void selectGeneratedCourse() => state = state.copyWith(
        selectedRouteIdx: -1,
        generatedCourseSelected: true,
      );

  /// place_detail_screen에서 "안내 시작" 버튼 탭 시 호출
  /// map_overlay의 ref.listen이 감지하여 _onStartModeBCourse를 실행
  void startRoute() => state = state.copyWith(navPending: true);

  void clearNavPending() => state = state.copyWith(navPending: false);

  void reset() => state = const RouteSearchState();
}
