import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../explore/presentation/providers/explore_provider.dart';
import '../../../user/presentation/providers/user_provider.dart';
import '../../data/repositories/mode_b_repository_impl.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';
import 'cart_provider.dart';

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
    this.activeSpotTag,
    this.nearbyCoursesActive = false,
    this.searchedSpots = const [],
    this.difficultyFilter = '전체',
    this.selectedSpotIdx = -1,
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

  /// 현재 활성 스팟 태그 (null = 아무것도 선택 안 됨)
  final SpotTag? activeSpotTag;

  /// "주변 코스" 모드 활성 여부 (activeSpotTag와 배타적)
  final bool nearbyCoursesActive;

  /// 태그 검색으로 찾은 스팟 목록
  final List<SpotEntity> searchedSpots;

  /// 스팟 목록에서 선택된 인덱스
  final int selectedSpotIdx;

  /// 난이도 필터: '전체' | '쉬움' | '보통' | '어려움'
  final String difficultyFilter;

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

  /// 난이도 필터 적용한 전체 목록
  List<TouristRouteEntity> get filteredRoutes {
    if (difficultyFilter == '전체') return allRoutes;
    return allRoutes.where((r) {
      if (r.tags.isEmpty) return true;
      return r.tags.any((t) => t.contains(difficultyFilter));
    }).toList();
  }

  bool get hasMore => displayedRoutes.length < filteredRoutes.length;
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
    Object? activeSpotTag = _kKeep,
    bool? nearbyCoursesActive,
    List<SpotEntity>? searchedSpots,
    int? selectedSpotIdx,
    String? difficultyFilter,
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
        activeSpotTag: identical(activeSpotTag, _kKeep)
            ? this.activeSpotTag
            : activeSpotTag as SpotTag?,
        nearbyCoursesActive: nearbyCoursesActive ?? this.nearbyCoursesActive,
        searchedSpots: searchedSpots ?? this.searchedSpots,
        selectedSpotIdx: selectedSpotIdx ?? this.selectedSpotIdx,
        difficultyFilter: difficultyFilter ?? this.difficultyFilter,
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
      activeSpotTag: null,
      nearbyCoursesActive: true,
      searchedSpots: [],
      selectedSpotIdx: -1,
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

  // ── 스팟 태그 선택 (단일 선택) ──────────────────────────────────

  void selectSpotTag(SpotTag tag) {
    if (state.activeSpotTag == tag) {
      // 같은 태그 재탭 → 해제
      state = state.copyWith(
        activeSpotTag: null,
        nearbyCoursesActive: false,
        searchedSpots: [],
        selectedSpotIdx: -1,
      );
    } else {
      state = state.copyWith(
        activeSpotTag: tag,
        nearbyCoursesActive: false,
        searchedSpots: [],
        selectedSpotIdx: -1,
        allRoutes: [],
        displayedRoutes: [],
        selectedRouteIdx: -1,
        generatedCourse: null,
        generatedCourseSelected: false,
      );
    }
  }

  // ── "주변 코스" 모드 토글 ──────────────────────────────────────

  void toggleNearbyCourses() {
    if (state.nearbyCoursesActive) {
      state = state.copyWith(
        nearbyCoursesActive: false,
        allRoutes: [],
        displayedRoutes: [],
        selectedRouteIdx: -1,
      );
    } else {
      state = state.copyWith(
        nearbyCoursesActive: true,
        activeSpotTag: null,
        searchedSpots: [],
        selectedSpotIdx: -1,
      );
    }
  }

  // ── 스팟 검색 (태그 기반) ─────────────────────────────────────

  Future<void> searchSpotsForActiveTag({
    double lat = 37.5635,
    double lng = 126.9869,
  }) async {
    final tag = state.activeSpotTag;
    if (tag == null) return;

    state = state.copyWith(isFetchingSpots: true, searchedSpots: [], selectedSpotIdx: -1);

    try {
      final spots = await ref.read(modeBRepositoryProvider).searchSpots(
            latitude: lat,
            longitude: lng,
            tags: {tag},
            transport: state.transport,
          );
      state = state.copyWith(searchedSpots: spots, isFetchingSpots: false);
    } catch (_) {
      state = state.copyWith(isFetchingSpots: false);
    }
  }

  // ── 스팟 선택 ──────────────────────────────────────────────────

  void selectSpot(int idx) => state = state.copyWith(selectedSpotIdx: idx);

  // ── 스팟 조합 코스 생성 ──────────────────────────────────────────

  Future<void> generateCourseFromSpots(
    FoodEntity food, {
    double lat = 37.5635,
    double lng = 126.9869,
    List<SpotEntity> cartItems = const [],
  }) async {
    state = state.copyWith(isFetchingSpots: true, generatedCourse: null);

    try {
      List<SpotEntity> baseSpots;
      if (cartItems.isNotEmpty) {
        baseSpots = cartItems;
      } else {
        baseSpots = await ref.read(modeBRepositoryProvider).searchSpots(
              latitude: lat,
              longitude: lng,
              tags: state.activeSpotTag != null ? {state.activeSpotTag!} : {},
              transport: state.transport,
            );
      }

      if (baseSpots.isEmpty) {
        state = state.copyWith(isFetchingSpots: false);
        return;
      }

      // 카트 기반: 선택 스팟 전부 포함(TSP) / 앱 자동: 반경 내 자동 선택(최대 5개)
      var course = await ref.read(modeBRepositoryProvider).generateCourse(
            spots: cartItems.isNotEmpty ? const [] : baseSpots,
            userLat: lat,
            userLng: lng,
            targetKcal: food.kcal,
            transport: state.transport,
            mandatorySpots: cartItems.isNotEmpty ? baseSpots : const [],
          );

      // 카트 기반 코스가 칼로리 80% 미달 시 → 동일 태그 스팟을 optional 풀로 보충
      // 카트 스팟은 mandatorySpots로 전달해 항상 포함 보장
      List<SpotEntity> optionalPool = [];
      if (cartItems.isNotEmpty &&
          (course == null || course.kcal < food.kcal * 0.8)) {
        final extraTags = cartItems
            .map((s) => _spotTypeToTag(s.type))
            .whereType<SpotTag>()
            .toSet();

        if (extraTags.isNotEmpty) {
          final extraSpots = await ref.read(modeBRepositoryProvider).searchSpots(
                latitude: lat,
                longitude: lng,
                tags: extraTags,
                transport: state.transport,
              );

          final cartIds = baseSpots.map((s) => s.id).toSet();
          optionalPool = extraSpots.where((s) => !cartIds.contains(s.id)).toList();

          course = await ref.read(modeBRepositoryProvider).generateCourse(
                spots: optionalPool,
                userLat: lat,
                userLng: lng,
                targetKcal: food.kcal,
                transport: state.transport,
                mandatorySpots: baseSpots,
              );
        }
      }

      // 코스에 자동 추가된 스팟을 장바구니에 동기화
      // (waypoint 좌표는 SpotEntity에서 그대로 복사되므로 정확히 매칭됨)
      if (course != null) {
        final candidateMap = <String, SpotEntity>{
          for (final s in [...baseSpots, ...optionalPool]) '${s.lat}_${s.lng}': s,
        };
        final cartNotifier = ref.read(cartProvider.notifier);
        for (final wp in course.waypoints) {
          if (wp.type == '출발지') continue;
          final spot = candidateMap['${wp.lat}_${wp.lng}'];
          if (spot != null) cartNotifier.add(spot);
        }
      }

      if (course != null) {
        debugPrint('[ModeBNav] 생성 코스 좌표 (에뮬레이터 테스트용):');
        if (course.startLat != null && course.startLng != null) {
          debugPrint('  출발지: ${course.startLat}, ${course.startLng}');
        }
        for (final wp in course.waypoints) {
          debugPrint('  ${wp.name}: ${wp.lat}, ${wp.lng}');
        }
      }

      state = state.copyWith(
        generatedCourse: course,
        isFetchingSpots: false,
      );
    } catch (_) {
      state = state.copyWith(isFetchingSpots: false);
    }
  }

  SpotTag? _spotTypeToTag(String type) => switch (type) {
        'tourist_sight' => SpotTag.touristSight,
        'culture' => SpotTag.culture,
        'event' => SpotTag.event,
        'sports' => SpotTag.sports,
        'shopping' => SpotTag.shopping,
        _ => null,
      };

  // ── 더 보기 ────────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final nextStart = state.displayedRoutes.length;
    final nextBatch = state.filteredRoutes.skip(nextStart).take(_pageSize).toList();

    state = state.copyWith(
      displayedRoutes: [...state.displayedRoutes, ...nextBatch],
      isLoadingMore: false,
    );

    _enrichAndUpdate(startIdx: nextStart, batch: nextBatch);
  }

  // ── 난이도 필터 ─────────────────────────────────────────────────

  void setDifficultyFilter(String filter) {
    final filtered = filter == '전체'
        ? state.allRoutes
        : state.allRoutes.where((r) {
            if (r.tags.isEmpty) return true;
            return r.tags.any((t) => t.contains(filter));
          }).toList();
    state = state.copyWith(
      difficultyFilter: filter,
      selectedRouteIdx: -1,
      displayedRoutes: filtered.take(_pageSize).toList(),
    );
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

  // ── Transport ─────────────────────────────────────────────────

  void setTransport(String t, FoodEntity food,
      {double lat = 37.5635, double lng = 126.9869}) {
    state = state.copyWith(
      transport: t,
      selectedRouteIdx: 0,
      generatedCourse: null,
      generatedCourseSelected: false,
    );
    if (state.nearbyCoursesActive) {
      loadRoutes(food, lat: lat, lng: lng);
    } else if (state.activeSpotTag != null) {
      searchSpotsForActiveTag(lat: lat, lng: lng);
    }
  }

  // ── 루트 선택 / 시작 ───────────────────────────────────────────

  void selectRoute(int idx) => state = state.copyWith(
        selectedRouteIdx: idx,
        generatedCourseSelected: false,
      );

  void selectGeneratedCourse() => state = state.copyWith(
        selectedRouteIdx: -1,
        generatedCourseSelected: true,
      );

  /// place_detail_screen에서 "안내 시작" 버튼 탭 시 호출
  void startRoute() => state = state.copyWith(navPending: true);

  void clearNavPending() => state = state.copyWith(navPending: false);

  /// 폴리라인 페치 후 실제 도로 거리 기반으로 거리/시간/칼로리 갱신
  void updateGeneratedCourseMetrics({
    required double distanceKm,
    required int durationMinutes,
    required int kcal,
  }) {
    final course = state.generatedCourse;
    if (course == null) return;
    state = state.copyWith(
      generatedCourse: course.copyWith(
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        kcal: kcal,
      ),
    );
  }

  void reset() => state = const RouteSearchState();
}
