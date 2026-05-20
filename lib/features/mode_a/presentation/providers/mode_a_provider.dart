import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/mode_a_repository_impl.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

part 'mode_a_provider.g.dart';

// keepAlive: 탭 이동 후에도 상태 유지
@Riverpod(keepAlive: true)
ModeARepository modeARepository(ModeARepositoryRef ref) => ModeARepositoryImpl();

// ─── Route search state ───────────────────────────────────────
class ModeAState {
  const ModeAState({
    this.from = '광화문역 5번 출구',
    this.to = '',
    this.transport = 'walk',
    this.routeResult,
    this.restaurants = const [],
    this.isLoading = false,
    this.error,
  });

  final String from;
  final String to;
  final String transport;
  final RouteResultEntity? routeResult;
  final List<RestaurantEntity> restaurants;
  final bool isLoading;
  final String? error;

  ModeAState copyWith({
    String? from,
    String? to,
    String? transport,
    RouteResultEntity? routeResult,
    List<RestaurantEntity>? restaurants,
    bool? isLoading,
    String? error,
  }) {
    return ModeAState(
      from: from ?? this.from,
      to: to ?? this.to,
      transport: transport ?? this.transport,
      routeResult: routeResult ?? this.routeResult,
      restaurants: restaurants ?? this.restaurants,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// class ModeA → generates modeAProvider
@riverpod
class ModeA extends _$ModeA {
  @override
  ModeAState build() => const ModeAState();

  void setFrom(String v) => state = state.copyWith(from: v);
  void setTo(String v) => state = state.copyWith(to: v);

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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final weightKg = ref.read(userProfileProvider).weightKg;
      final result = await ref.read(modeARepositoryProvider).getRoute(
            from: state.from,
            to: state.to,
            transport: state.transport,
            weightKg: weightKg,
          );
      state = state.copyWith(routeResult: result, isLoading: false);
      await _loadRestaurants(result.kcalBurn);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadRestaurants(int targetKcal) async {
    final restaurants =
        await ref.read(modeARepositoryProvider).getNearbyRestaurants(
              latitude: 37.5635,
              longitude: 126.9869,
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
