import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/mode_a_repository_impl.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/entities/waypoint_candidate_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';
import '../../../explore/presentation/providers/explore_provider.dart';
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
ModeARepository modeARepository(ModeARepositoryRef ref) =>
    ModeARepositoryImpl(foodCatalogRepo: ref.watch(foodCatalogRepositoryProvider));

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
    // 도착지 근처 탭 — 음식점 탭은 도착 전엔 숨기므로 기본은 관광지
    this.nearbyTab = ModeANearbyTab.sight,
    this.nearbyPlaces = const [],
    this.nearbyDurunubi = const [],
    this.nearbyLoading = false,
    this.hasArrived = false,
    this.arrivalKcal,
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
  /// 도착 후 실측 소모 kcal이 확정되면 true — 결과 시트가 "예상"에서 "실제" 표시로
  /// 전환되고, 음식점 탭이 노출된다.
  final bool hasArrived;
  final double? arrivalKcal;

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
    Object? routeResult = _kRemove,
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
    bool? hasArrived,
    Object? arrivalKcal = _kRemove,
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
      routeResult: identical(routeResult, _kRemove)
          ? this.routeResult
          : routeResult as RouteResultEntity?,
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
      hasArrived: hasArrived ?? this.hasArrived,
      arrivalKcal:
          identical(arrivalKcal, _kRemove) ? this.arrivalKcal : arrivalKcal as double?,
    );
  }
}

@Riverpod(keepAlive: true)
class ModeA extends _$ModeA {
  // build()에서 _loadFromPrefs()를 자동 호출하지 않는다 — 안내 시작 전 강제종료 시
  // 경로(routeResult)는 저장되지 않는데 좌표만 복원되면 목적지 마커만 지도에 덩그러니
  // 남는 문제가 있었다. 좌표 복원은 "활성 안내가 있었다"는 확실한 신호가 있을 때만
  // restoreFromPrefs()를 통해 명시적으로 수행한다(splash_screen.dart의
  // _tryRestoreModeANav() 참고 — 복원 후 search()까지 다시 호출해 경로를 재생성함).
  @override
  ModeAState build() => const ModeAState();

  /// 스플래시 화면의 앱 재시작 복원 흐름(활성 안내가 있었을 때만)에서 호출 —
  /// _loadFromPrefs()가 끝날 때까지 await 가능하도록 감싼 public 진입점.
  Future<void> restoreFromPrefs() => _loadFromPrefs();

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
  /// 목적지가 바뀌면 기존 routeResult는 옛 목적지 기준 경로라 항상 무효 — 지도에
  /// 옛 폴리라인이 남는 버그(코스 재생성 전까지 안 지워짐) 방지를 위해 무조건 초기화.
  void setDestCoords(double? lat, double? lng, String label) {
    state = state.copyWith(
      to: label,
      destLat: lat,
      destLng: lng,
      routeResult: null,
      destIsRestaurant: false,
      destKcal: 0,
      waypointCandidates: const [],
      nearbyTab: ModeANearbyTab.sight,
      nearbyPlaces: const [],
      nearbyDurunubi: const [],
      hasArrived: false,
      arrivalKcal: null,
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
    // 이전 검색이 아직 진행 중이면 무시 — 중복 호출 시 두 응답이 순서 없이 도착해
    // _drawModeAPolyline이 겹쳐 실행되며 지도에 이전 코스가 남는 문제를 방지한다.
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final metrics = ref.read(userProfileProvider).toBodyMetrics();
      // gpx export 테스트(test/mode_a_gpx_export/export_route_gpx_test.dart)용 좌표 로그 —
      // 실제 앱에서 코스를 생성하면 여기 찍힌 origin/waypoints/dest/transport를 그대로
      // 테스트 상수에 복사해 동일한 경로를 재현할 수 있다.
      debugPrint('[ModeA][gpx-test-input] transport=${state.transport} '
          'origin=(${state.originLat}, ${state.originLng}) '
          'waypoints=${state.waypoints.map((w) => '(${w.latitude}, ${w.longitude})').toList()} '
          'dest=(${state.destLat}, ${state.destLng})');
      final result = await ref.read(modeARepositoryProvider).getRoute(
            from: state.from,
            to: state.to,
            originLat: state.originLat,
            originLng: state.originLng,
            destLat: state.destLat,
            destLng: state.destLng,
            transport: state.transport,
            metrics: metrics,
            waypoints: state.waypoints,
          );
      debugPrint('[ModeA][gpx-test-input] result: source=${result.routeSource} '
          'distanceKm=${result.distanceKm} durationSec=${result.durationSeconds} '
          'kcalBurn=${result.kcalBurn} points=${result.routePoints.length}');
      state = state.copyWith(
        routeResult: result,
        isLoading: false,
        hasArrived: false,
        arrivalKcal: null,
      );
      // 도착지가 음식점/카페가 아닌 경우에만 주변 식당 로드
      if (!state.destIsRestaurant) {
        await _loadRestaurants(result.kcalBurn);
      }
      // 기본 탭(음식점 제외)은 사용자가 탭을 직접 누르기 전까지 아무도 안 채워주므로
      // 여기서 현재 선택된 탭 데이터를 미리 로드해둔다 — 안 그러면 도착 전 기본 탭인
      // 관광지가 처음엔 빈 목록으로 보인다.
      await _fetchNearbyTabData(state.nearbyTab);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadRestaurants(int targetKcal, {double? lat, double? lng}) async {
    final rLat = lat ?? state.destLat ?? 37.5635;
    final rLng = lng ?? state.destLng ?? 126.9869;
    final restaurants =
        await ref.read(modeARepositoryProvider).getNearbyRestaurants(
              latitude: rLat,
              longitude: rLng,
              radiusKm: 2.0,
              targetKcal: targetKcal,
            );
    state = state.copyWith(restaurants: restaurants);
  }

  /// 목적지 도착 시 호출 — 실측 소모 kcal을 확정하고, 검색 상태(출발/경유/도착지)를
  /// 초기화한다. routeResult는 유지해 결과 시트가 도착 요약(거리/시간/실제 kcal)을
  /// 계속 보여줄 수 있게 한다. 좌표는 초기화 전에 캡처해 도착지 기준 맛집 재조회에 쓴다.
  Future<void> markArrived(double kcal) async {
    final lat = state.destLat;
    final lng = state.destLng;
    state = state.copyWith(
      hasArrived: true,
      arrivalKcal: kcal,
      from: '현재 위치',
      to: '',
      originLat: null,
      originLng: null,
      destLat: null,
      destLng: null,
      waypoints: const [],
      nearbyTab: ModeANearbyTab.restaurant,
    );
    if (!state.destIsRestaurant && lat != null && lng != null) {
      await _loadRestaurants(kcal.round(), lat: lat, lng: lng);
    }
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
      final metrics = ref.read(userProfileProvider).toBodyMetrics();
      final candidates = await ref.read(modeARepositoryProvider).getWaypointCandidates(
            midLat: midLat,
            midLng: midLng,
            originLat: origin.$1!,
            originLng: origin.$2!,
            destLat: dest.$1!,
            destLng: dest.$2!,
            extraKcalNeeded: extraKcalNeeded,
            transport: state.transport,
            metrics: metrics,
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
    state = state.copyWith(nearbyTab: tab);
    await _fetchNearbyTabData(tab);
  }

  /// [tab]에 해당하는 주변 데이터를 가져와 state에 반영한다. 음식점 탭은 별도
  /// 흐름(_loadRestaurants — 목표 kcal 기준 food_catalog 매칭)에서 관리하므로 여기선
  /// 건드리지 않는다. search()가 초기 기본 탭을 채울 때와 switchNearbyTab()이 탭 전환
  /// 시 채울 때 공용으로 쓴다.
  Future<void> _fetchNearbyTabData(ModeANearbyTab tab) async {
    if (tab == ModeANearbyTab.restaurant) return;
    state = state.copyWith(nearbyLoading: true);
    final lat = state.destLat ?? 37.5635;
    final lng = state.destLng ?? 126.9869;
    try {
      if (tab == ModeANearbyTab.durunubi) {
        final metrics = ref.read(userProfileProvider).toBodyMetrics();
        final courses = await ref
            .read(modeARepositoryProvider)
            .getNearbyDurunubiCourses(latitude: lat, longitude: lng, metrics: metrics);
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

}
