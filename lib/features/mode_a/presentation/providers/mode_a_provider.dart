import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/mode_a_repository_impl.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/entities/waypoint_candidate_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';
import '../../../map/domain/entities/place_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

part 'mode_a_provider.g.dart';

enum ModeANearbyTab {
  restaurant('음식점', null),
  sight('관광지', 12),
  culture('문화시설', 14),
  festival('축제·행사', 15),
  course('여행코스', 25),
  durunubi('두루누비', null);

  const ModeANearbyTab(this.label, this.contentTypeId);
  final String label;
  final int? contentTypeId;
}

const _kRemove = Object();

@Riverpod(keepAlive: true)
ModeARepository modeARepository(ModeARepositoryRef ref) => ModeARepositoryImpl();

class ModeAState {
  const ModeAState({
    this.from = '현재 위치',
    this.to = '',
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.originIsCurrentLocation = false,
    this.transport = 'walk',
    this.waypoints = const [],
    this.routeResult,
    this.restaurants = const [],
    this.isLoading = false,
    this.error,
    // Phase 3: calorie matching
    this.destIsRestaurant = false,
    this.destKcal = 0,
    // Phase 4: waypoint candidates
    this.waypointCandidates = const [],
    this.loadingCandidates = false,
    // 도착지 근처 탭
    this.nearbyTab = ModeANearbyTab.restaurant,
    this.nearbyPlaces = const [],
    this.nearbyDurunubi = const [],
    this.nearbyLoading = false,
  });

  final String from;
  final String to;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final bool originIsCurrentLocation;
  final String transport;
  final List<RouteWaypoint> waypoints;
  final RouteResultEntity? routeResult;
  final List<RestaurantEntity> restaurants;
  final bool isLoading;
  final String? error;

  // Phase 3: calorie matching (목적지가 음식점/카페인 경우)
  final bool destIsRestaurant;
  final int destKcal;

  // Phase 4: waypoint candidates
  final List<WaypointCandidateEntity> waypointCandidates;
  final bool loadingCandidates;

  // 도착지 근처 탭
  final ModeANearbyTab nearbyTab;
  final List<PlaceEntity> nearbyPlaces;
  final List<TouristRouteEntity> nearbyDurunubi;
  final bool nearbyLoading;

  ModeAState copyWith({
    String? from,
    String? to,
    Object? originLat = _kRemove,
    Object? originLng = _kRemove,
    Object? destLat = _kRemove,
    Object? destLng = _kRemove,
    bool? originIsCurrentLocation,
    String? transport,
    List<RouteWaypoint>? waypoints,
    RouteResultEntity? routeResult,
    List<RestaurantEntity>? restaurants,
    bool? isLoading,
    String? error,
    bool? destIsRestaurant,
    int? destKcal,
    List<WaypointCandidateEntity>? waypointCandidates,
    bool? loadingCandidates,
    ModeANearbyTab? nearbyTab,
    List<PlaceEntity>? nearbyPlaces,
    List<TouristRouteEntity>? nearbyDurunubi,
    bool? nearbyLoading,
  }) {
    return ModeAState(
      from: from ?? this.from,
      to: to ?? this.to,
      originLat: identical(originLat, _kRemove) ? this.originLat : originLat as double?,
      originLng: identical(originLng, _kRemove) ? this.originLng : originLng as double?,
      destLat: identical(destLat, _kRemove) ? this.destLat : destLat as double?,
      destLng: identical(destLng, _kRemove) ? this.destLng : destLng as double?,
      originIsCurrentLocation: originIsCurrentLocation ?? this.originIsCurrentLocation,
      transport: transport ?? this.transport,
      waypoints: waypoints ?? this.waypoints,
      routeResult: routeResult ?? this.routeResult,
      restaurants: restaurants ?? this.restaurants,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      destIsRestaurant: destIsRestaurant ?? this.destIsRestaurant,
      destKcal: destKcal ?? this.destKcal,
      waypointCandidates: waypointCandidates ?? this.waypointCandidates,
      loadingCandidates: loadingCandidates ?? this.loadingCandidates,
      nearbyTab: nearbyTab ?? this.nearbyTab,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      nearbyDurunubi: nearbyDurunubi ?? this.nearbyDurunubi,
      nearbyLoading: nearbyLoading ?? this.nearbyLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class ModeA extends _$ModeA {
  @override
  ModeAState build() {
    _loadFromPrefs();
    return const ModeAState();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString('mode_a_from');
    if (from == null) return;
    final originLat = prefs.getDouble('mode_a_origin_lat');
    final originLng = prefs.getDouble('mode_a_origin_lng');
    final to = prefs.getString('mode_a_to') ?? '';
    final destLat = prefs.getDouble('mode_a_dest_lat');
    final destLng = prefs.getDouble('mode_a_dest_lng');
    final wpCount = prefs.getInt('mode_a_wp_count') ?? 0;
    final wps = <RouteWaypoint>[];
    for (var i = 0; i < wpCount; i++) {
      final name = prefs.getString('mode_a_wp_${i}_name') ?? '경유지 ${i + 1}';
      final lat = prefs.getDouble('mode_a_wp_${i}_lat');
      final lng = prefs.getDouble('mode_a_wp_${i}_lng');
      if (lat != null && lng != null) {
        wps.add(RouteWaypoint(name: name, latitude: lat, longitude: lng));
      }
    }
    state = state.copyWith(
      from: from,
      originLat: originLat,
      originLng: originLng,
      to: to,
      destLat: destLat,
      destLng: destLng,
      waypoints: wps,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mode_a_from', state.from);
    if (state.originLat != null) await prefs.setDouble('mode_a_origin_lat', state.originLat!);
    if (state.originLng != null) await prefs.setDouble('mode_a_origin_lng', state.originLng!);
    await prefs.setString('mode_a_to', state.to);
    if (state.destLat != null) await prefs.setDouble('mode_a_dest_lat', state.destLat!);
    if (state.destLng != null) await prefs.setDouble('mode_a_dest_lng', state.destLng!);
    await prefs.setInt('mode_a_wp_count', state.waypoints.length);
    for (var i = 0; i < state.waypoints.length; i++) {
      final wp = state.waypoints[i];
      await prefs.setString('mode_a_wp_${i}_name', wp.name);
      await prefs.setDouble('mode_a_wp_${i}_lat', wp.latitude);
      await prefs.setDouble('mode_a_wp_${i}_lng', wp.longitude);
    }
  }

  void setFrom(String v) => state = state.copyWith(from: v);
  void setTo(String v) => state = state.copyWith(to: v);

  void setOriginGps(double lat, double lng, String label) {
    state = state.copyWith(
      from: label,
      originLat: lat,
      originLng: lng,
      originIsCurrentLocation: true,
    );
    _save();
  }

  /// 도착지 좌표 설정. lat/lng이 null이면 도착지 초기화.
  void setDestCoords(double? lat, double? lng, String label) {
    state = state.copyWith(
      to: label,
      destLat: lat,
      destLng: lng,
      routeResult: label.isEmpty ? null : state.routeResult,
      destIsRestaurant: false,
      destKcal: 0,
      waypointCandidates: const [],
      nearbyTab: ModeANearbyTab.restaurant,
      nearbyPlaces: const [],
      nearbyDurunubi: const [],
    );
    _save();
  }

  /// Phase 3: 도착지가 음식점/카페일 때 kcal 설정
  void setDestRestaurant({required bool isRestaurant, required int kcal}) {
    state = state.copyWith(
      destIsRestaurant: isRestaurant,
      destKcal: kcal,
    );
  }

  void addWaypoint(RouteWaypoint wp) {
    if (state.waypoints.length >= 3) return;
    state = state.copyWith(waypoints: [...state.waypoints, wp]);
    _save();
  }

  void removeWaypoint(int index) {
    final list = [...state.waypoints];
    list.removeAt(index);
    state = state.copyWith(waypoints: list);
    _save();
  }

  /// ReorderableListView의 onReorderItem 콜백에서 호출.
  /// onReorderItem은 newIndex가 제거 후 삽입 위치이므로 그대로 사용.
  void reorderWaypoint(int oldIndex, int newIndex) {
    final list = [...state.waypoints];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(waypoints: list);
    _save();
  }

  void setTransport(String t) {
    if (state.transport == t) return;
    // 이동수단이 바뀌면 기존 경로는 무효 — 재검색 필요
    state = ModeAState(
      from: state.from,
      to: state.to,
      originLat: state.originLat,
      originLng: state.originLng,
      destLat: state.destLat,
      destLng: state.destLng,
      originIsCurrentLocation: state.originIsCurrentLocation,
      transport: t,
      waypoints: state.waypoints,
      destIsRestaurant: state.destIsRestaurant,
      destKcal: state.destKcal,
    );
  }

  Future<void> search() async {
    if (state.from.isEmpty || state.to.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final weightKg = ref.read(userProfileProvider).weightKg;
      final result = await ref.read(modeARepositoryProvider).getRoute(
            from: state.from,
            to: state.to,
            originLat: state.originLat,
            originLng: state.originLng,
            destLat: state.destLat,
            destLng: state.destLng,
            transport: state.transport,
            weightKg: weightKg,
            waypoints: state.waypoints,
          );
      state = state.copyWith(routeResult: result, isLoading: false);
      // 도착지가 음식점/카페가 아닌 경우에만 주변 식당 로드
      if (!state.destIsRestaurant) {
        await _loadRestaurants(result.kcalBurn);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadRestaurants(int targetKcal) async {
    final lat = state.destLat ?? 37.5635;
    final lng = state.destLng ?? 126.9869;
    final restaurants =
        await ref.read(modeARepositoryProvider).getNearbyRestaurants(
              latitude: lat,
              longitude: lng,
              radiusKm: 2.0,
              targetKcal: targetKcal,
            );
    state = state.copyWith(restaurants: restaurants);
  }

  /// Phase 4: 경유지 후보 로드
  Future<void> loadWaypointCandidates(int extraKcalNeeded) async {
    final origin = (state.originLat, state.originLng);
    final dest = (state.destLat, state.destLng);
    if (origin.$1 == null || origin.$2 == null ||
        dest.$1 == null || dest.$2 == null) {
      return;
    }

    // 경로 중간점 계산
    final midLat = (origin.$1! + dest.$1!) / 2;
    final midLng = (origin.$2! + dest.$2!) / 2;

    state = state.copyWith(loadingCandidates: true, waypointCandidates: const []);
    try {
      final weightKg = ref.read(userProfileProvider).weightKg;
      final candidates = await ref.read(modeARepositoryProvider).getWaypointCandidates(
            midLat: midLat,
            midLng: midLng,
            originLat: origin.$1!,
            originLng: origin.$2!,
            destLat: dest.$1!,
            destLng: dest.$2!,
            extraKcalNeeded: extraKcalNeeded,
            transport: state.transport,
            weightKg: weightKg,
          );
      state = state.copyWith(
        waypointCandidates: candidates,
        loadingCandidates: false,
      );
    } catch (e) {
      state = state.copyWith(loadingCandidates: false);
    }
  }

  Future<void> switchNearbyTab(ModeANearbyTab tab) async {
    if (state.nearbyTab == tab) return;
    state = state.copyWith(nearbyTab: tab, nearbyLoading: true);
    final lat = state.destLat ?? 37.5635;
    final lng = state.destLng ?? 126.9869;
    try {
      if (tab == ModeANearbyTab.restaurant) {
        state = state.copyWith(nearbyLoading: false);
        return;
      }
      if (tab == ModeANearbyTab.durunubi) {
        final courses = await ref
            .read(modeARepositoryProvider)
            .getNearbyDurunubiCourses(latitude: lat, longitude: lng);
        state = state.copyWith(nearbyDurunubi: courses, nearbyLoading: false);
        return;
      }
      final places = await ref.read(modeARepositoryProvider).getNearbyPlaces(
            latitude: lat,
            longitude: lng,
            radiusKm: 2.0,
            contentTypeId: tab.contentTypeId!,
          );
      state = state.copyWith(nearbyPlaces: places, nearbyLoading: false);
    } catch (_) {
      state = state.copyWith(nearbyLoading: false);
    }
  }

  void clearRouteResult() {
    state = ModeAState(
      from: state.from,
      to: state.to,
      originLat: state.originLat,
      originLng: state.originLng,
      destLat: state.destLat,
      destLng: state.destLng,
      originIsCurrentLocation: state.originIsCurrentLocation,
      transport: state.transport,
      waypoints: state.waypoints,
      destIsRestaurant: state.destIsRestaurant,
      destKcal: state.destKcal,
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final wpCount = prefs.getInt('mode_a_wp_count') ?? 0;
    for (var i = 0; i < wpCount; i++) {
      await prefs.remove('mode_a_wp_${i}_name');
      await prefs.remove('mode_a_wp_${i}_lat');
      await prefs.remove('mode_a_wp_${i}_lng');
    }
    await prefs.remove('mode_a_from');
    await prefs.remove('mode_a_origin_lat');
    await prefs.remove('mode_a_origin_lng');
    await prefs.remove('mode_a_to');
    await prefs.remove('mode_a_dest_lat');
    await prefs.remove('mode_a_dest_lng');
    await prefs.remove('mode_a_wp_count');
    state = const ModeAState();
  }

  int _calcKcal(String transport, double weight, int durationSec) {
    const met = {'walk': 3.5, 'bike': 6.0, 'transit': 1.5};
    return ((met[transport] ?? 3.5) * weight * durationSec / 3600).round();
  }
}
