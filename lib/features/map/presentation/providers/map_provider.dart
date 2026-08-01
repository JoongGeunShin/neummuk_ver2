import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/place_repository_impl.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/repositories/place_repository.dart';

part 'map_provider.g.dart';

@riverpod
PlaceRepository placeRepository(Ref ref) => PlaceRepositoryImpl();

// ── State ──────────────────────────────────────────────────────
class MapSearchState {
  const MapSearchState({
    this.places = const [],
    this.isLoading = false,
    this.selectedCategory = '전체',
    this.searchQuery = '',
    this.centerLat,
    this.centerLng,
    this.error,
    Object? selectedPlace = _keep,
  }) : _selectedPlace = selectedPlace;

  final List<PlaceEntity> places;
  final bool isLoading;
  final String selectedCategory;
  final String searchQuery;
  final double? centerLat;
  final double? centerLng;
  final String? error;
  final Object? _selectedPlace;

  PlaceEntity? get selectedPlace =>
      _selectedPlace == _keep ? null : _selectedPlace as PlaceEntity?;

  static const _keep = Object();

  MapSearchState copyWith({
    List<PlaceEntity>? places,
    bool? isLoading,
    String? selectedCategory,
    String? searchQuery,
    double? centerLat,
    double? centerLng,
    String? error,
    Object? selectedPlace = _keep,
  }) =>
      MapSearchState(
        places: places ?? this.places,
        isLoading: isLoading ?? this.isLoading,
        selectedCategory: selectedCategory ?? this.selectedCategory,
        searchQuery: searchQuery ?? this.searchQuery,
        centerLat: centerLat ?? this.centerLat,
        centerLng: centerLng ?? this.centerLng,
        error: error ?? this.error,
        selectedPlace: selectedPlace,
      );
}

// ── Notifier ───────────────────────────────────────────────────
@riverpod
class MapSearchNotifier extends _$MapSearchNotifier {
  @override
  MapSearchState build() => const MapSearchState();

  /// 외부에서 이미 가져온 장소 목록을 그대로 주입한다(예: Mode A 도착 후 food_catalog로
  /// 매칭한 맛집을 탐색 모드 지도에 보여줄 때) — 실검색(loadPlaces)과 달리 네트워크
  /// 호출 없이 상태만 갱신하며, 마커/카메라 fit은 map_overlay.dart의 기존
  /// places 리스너가 그대로 처리한다.
  void setPlaces(List<PlaceEntity> places, {double? centerLat, double? centerLng}) {
    state = state.copyWith(
      places: places,
      centerLat: centerLat ?? state.centerLat,
      centerLng: centerLng ?? state.centerLng,
    );
  }

  Future<void> loadPlaces(
    double lat,
    double lng, {
    String? keyword,
    bool isCategory = false,
    int radiusMeters = 3000,
  }) async {
    final effectiveKeyword =
        keyword ?? (state.selectedCategory == '전체' ? null : state.selectedCategory);
    state = state.copyWith(
      centerLat: lat,
      centerLng: lng,
      isLoading: true,
      error: null,
    );
    try {
      final places = await ref.read(placeRepositoryProvider).searchNearby(
            latitude: lat,
            longitude: lng,
            keyword: effectiveKeyword,
            isCategory: isCategory,
            radiusMeters: radiusMeters,
          );
      state = state.copyWith(places: places, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString(), places: []);
    }
  }

  Future<void> selectCategory(String category, {int radiusMeters = 3000}) async {
    state = state.copyWith(selectedCategory: category);
    final lat = state.centerLat ?? 37.5665;
    final lng = state.centerLng ?? 126.9780;
    await loadPlaces(lat, lng,
        keyword: category == '전체' ? null : category,
        isCategory: true,
        radiusMeters: radiusMeters);
  }

  Future<void> search(String query, {int radiusMeters = 3000}) async {
    state = state.copyWith(searchQuery: query);
    final lat = state.centerLat ?? 37.5665;
    final lng = state.centerLng ?? 126.9780;
    await loadPlaces(lat, lng,
        keyword: query.isNotEmpty ? query : null,
        radiusMeters: radiusMeters);
  }

  void selectPlace(PlaceEntity? place) {
    state = state.copyWith(selectedPlace: place);
  }

  void updateCenter(double lat, double lng) {
    state = state.copyWith(centerLat: lat, centerLng: lng);
  }
}
