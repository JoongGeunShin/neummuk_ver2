import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/mode_a_repository_impl.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

part 'mode_a_provider.g.dart';

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
    );
  }
}

@riverpod
class ModeA extends _$ModeA {
  @override
  ModeAState build() => const ModeAState();

  void setFrom(String v) => state = state.copyWith(from: v);
  void setTo(String v) => state = state.copyWith(to: v);

  void setOriginGps(double lat, double lng, String label) {
    state = state.copyWith(
      from: label,
      originLat: lat,
      originLng: lng,
      originIsCurrentLocation: true,
    );
  }

  void setDestCoords(double lat, double lng, String label) {
    state = state.copyWith(
      to: label,
      destLat: lat,
      destLng: lng,
    );
  }

  void addWaypoint(RouteWaypoint wp) {
    if (state.waypoints.length >= 3) return;
    state = state.copyWith(waypoints: [...state.waypoints, wp]);
  }

  void removeWaypoint(int index) {
    final list = [...state.waypoints];
    list.removeAt(index);
    state = state.copyWith(waypoints: list);
  }

  void setTransport(String t) {
    final prev = state.routeResult;
    if (prev == null) {
      state = state.copyWith(transport: t);
      return;
    }
    final weightKg = ref.read(userProfileProvider).weightKg;
    final kcal = _calcKcal(t, weightKg, prev.durationSeconds);
    state = state.copyWith(
      transport: t,
      routeResult: prev.copyWith(transport: t, kcalBurn: kcal),
    );
    _loadRestaurants(kcal);
  }

  Future<void> search() async {
    if (state.from.isEmpty || state.to.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final weightKg = ref.read(userProfileProvider).weightKg;
      final result = await ref.read(modeARepositoryProvider).getRoute(
            from: state.from,
            to: state.to,
            transport: state.transport,
            weightKg: weightKg,
            waypoints: state.waypoints,
          );
      state = state.copyWith(routeResult: result, isLoading: false);
      await _loadRestaurants(result.kcalBurn);
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

  int _calcKcal(String transport, double weight, int durationSec) {
    const met = {'walk': 3.5, 'bike': 6.0, 'transit': 1.5};
    return ((met[transport] ?? 3.5) * weight * durationSec / 3600).round();
  }
}
