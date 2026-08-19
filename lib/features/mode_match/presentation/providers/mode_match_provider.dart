import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../explore/presentation/providers/explore_provider.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../data/repositories/mode_match_repository_impl.dart';
import '../../domain/repositories/mode_match_repository.dart';

part 'mode_match_provider.g.dart';

@Riverpod(keepAlive: true)
ModeMatchRepository modeMatchRepository(ModeMatchRepositoryRef ref) =>
    ModeMatchRepositoryImpl(
      foodCatalogRepo: ref.watch(foodCatalogRepositoryProvider),
    );

class ModeMatchState {
  const ModeMatchState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  ModeMatchState copyWith({bool? isLoading, String? error}) => ModeMatchState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

@riverpod
class ModeMatch extends _$ModeMatch {
  @override
  ModeMatchState build() => const ModeMatchState();

  /// 오늘의 맞춤 맛집: targetKcal ±20% + 선호 카테고리(없으면 무관)로 매장을 찾는다.
  Future<List<RestaurantEntity>> findMatchedRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
    required List<String> preferredCategories,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref.read(modeMatchRepositoryProvider).getMatchedRestaurants(
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            targetKcal: targetKcal,
            preferredCategories: preferredCategories,
          );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return [];
    }
  }
}
