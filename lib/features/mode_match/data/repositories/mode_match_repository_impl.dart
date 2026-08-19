import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../../explore/domain/repositories/food_catalog_repository.dart';
import '../../../mode_a/data/services/kakao_food_place_search_service.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../domain/repositories/mode_match_repository.dart';

class ModeMatchRepositoryImpl implements ModeMatchRepository {
  ModeMatchRepositoryImpl({required FoodCatalogRepository foodCatalogRepo})
      : _foodCatalogRepo = foodCatalogRepo;

  final FoodCatalogRepository _foodCatalogRepo;

  String get _kakaoKey => AppEnv.kakaoRestApiKey;

  static const _kMaxFoodCandidates = 6;

  @override
  Future<List<RestaurantEntity>> getMatchedRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
    required List<String> preferredCategories,
  }) async {
    try {
      final nearKcal = await _foodCatalogRepo.getFoodsNearKcal(
          targetKcal.toDouble(), AppConstants.kcalMatchTolerancePct);
      if (nearKcal.isEmpty) return [];

      final matchedFoods = preferredCategories.isEmpty
          ? nearKcal
          : nearKcal
              .where((f) => preferredCategories.contains(f.category))
              .toList();
      if (matchedFoods.isEmpty) return [];

      final radiusM = (radiusKm * 1000).round();
      final candidates = matchedFoods.take(_kMaxFoodCandidates).toList();
      final results = await Future.wait(candidates.map((food) =>
          KakaoFoodPlaceSearchService.byKeyword(
            food: food,
            lat: latitude,
            lng: longitude,
            radiusM: radiusM,
            kakaoKey: _kakaoKey,
          )));

      final seen = <String>{};
      final merged = <RestaurantEntity>[];
      for (final list in results) {
        for (final r in list) {
          if (seen.add(r.id)) merged.add(r);
        }
      }
      merged.sort((a, b) => a.distanceM.compareTo(b.distanceM));
      return merged;
    } catch (e) {
      debugPrint('[ModeMatch] getMatchedRestaurants error: $e');
      return [];
    }
  }
}
