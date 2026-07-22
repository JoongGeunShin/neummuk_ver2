import 'package:neummuk_ver2/core/constants/app_constants.dart';
import 'package:neummuk_ver2/core/models/body_metrics.dart';
import 'package:neummuk_ver2/core/utils/geo_utils.dart';
import 'package:neummuk_ver2/features/mode_b/data/datasources/kakao_local_spots_datasource.dart';
import 'package:neummuk_ver2/features/mode_b/data/datasources/tmap_route_datasource.dart';
import 'package:neummuk_ver2/features/mode_b/data/datasources/tour_api_spots_datasource.dart';
import 'package:neummuk_ver2/features/mode_b/domain/entities/spot_entity.dart';
import 'package:neummuk_ver2/features/mode_b/domain/entities/tourist_route_entity.dart';
import 'package:neummuk_ver2/features/mode_b/domain/services/mode_b_course_generator.dart';

/// ModeBRepositoryImpl.searchSpots() + generateCourse()를 그대로 재현한다.
/// 앱에서 사용자가 위치 기준으로 "코스 생성"을 눌렀을 때와 동일한
/// 스팟 검색(Kakao Local + TourAPI) → 선택 → TMAP 실거리 보정 로직을 거친다.
/// (원본은 FoodCatalogRepository를 함께 받는 리포지토리라 이 테스트에서 그대로 못 씀 —
/// 코스 생성에 필요한 부분만 그대로 옮겨왔다.)
class RealCourseGenerator {
  RealCourseGenerator({required this.metrics});

  final BodyMetrics metrics;
  final _kakaoSpots = KakaoLocalSpotsDatasource();
  final _tourApiSpots = TourApiSpotsDatasource();
  final _tmapRoute = TmapRouteDatasource();
  final _generator = const ModeBCourseGenerator();

  Future<List<SpotEntity>> searchSpots({
    required double lat,
    required double lng,
    required String transport,
    Set<SpotTag> tags = const {},
  }) async {
    final radiusM =
        transport == 'bike' ? AppConstants.modeBBikeRadiusM : AppConstants.modeBWalkRadiusM;
    final effectiveTags = tags.isEmpty ? SpotTag.values.toSet() : tags;

    final kakaoCodes = <String>{};
    for (final tag in effectiveTags) {
      kakaoCodes.addAll(tag.kakaoGroupCodes);
    }
    final tourTypeIds = <int>[];
    for (final tag in effectiveTags) {
      final typeId = tag.tourApiContentTypeId;
      if (typeId != null) tourTypeIds.add(typeId);
    }

    final results = await Future.wait([
      kakaoCodes.isNotEmpty
          ? _kakaoSpots.fetchSpots(
              lat: lat, lng: lng, categoryGroupCodes: kakaoCodes.toList(), radiusM: radiusM)
          : Future.value(<SpotEntity>[]),
      tourTypeIds.isNotEmpty
          ? _tourApiSpots.fetchSpots(
              lat: lat, lng: lng, contentTypeIds: tourTypeIds, radiusM: radiusM)
          : Future.value(<SpotEntity>[]),
    ]);

    final kakaoSpots = results[0];
    final tourSpots = results[1];

    final combined = <SpotEntity>[...kakaoSpots];
    for (final ts in tourSpots) {
      final isDuplicate = kakaoSpots.any((ks) =>
          haversineDistanceKm(ks.lat, ks.lng, ts.lat, ts.lng) < 0.05 && ks.name == ts.name);
      if (!isDuplicate) combined.add(ts);
    }
    combined.sort((a, b) =>
        (a.distanceFromUserM ?? 99999).compareTo(b.distanceFromUserM ?? 99999));
    return combined;
  }

  Future<TouristRouteEntity?> generateCourse({
    required List<SpotEntity> spots,
    required double userLat,
    required double userLng,
    required int targetKcal,
    required String transport,
  }) async {
    final picked = _generator.select(
      spots: spots,
      userLat: userLat,
      userLng: userLng,
      targetKcal: targetKcal,
      transport: transport,
      metrics: metrics,
    );
    if (picked.selected.isEmpty) return null;

    final selectedIds = picked.selected.map((s) => s.id).toSet();
    final pool = spots.where((s) => !selectedIds.contains(s.id)).toList();
    var current = List<SpotEntity>.of(picked.selected);
    final tolerance = targetKcal * AppConstants.kcalMatchTolerancePct;
    TouristRouteEntity? result;

    const maxCorrections = 2;
    for (var i = 0; i <= maxCorrections; i++) {
      final realDistKm = await _tmapRoute.fetchRoundTripDistanceKm(
        startLat: userLat,
        startLng: userLng,
        orderedSpots: current,
      );

      result = _generator.buildRoute(
        selected: current,
        userLat: userLat,
        userLng: userLng,
        transport: transport,
        metrics: metrics,
        actualDistKmOverride: realDistKm,
      );
      if (result == null) return null;

      final diff = result.kcal - targetKcal;
      if (i == maxCorrections || diff.abs() <= tolerance) break;

      if (diff > 0 && current.length > picked.mandatoryCount && current.length > 1) {
        current = current.sublist(0, current.length - 1);
      } else if (diff < 0 && pool.isNotEmpty) {
        final next = pool.removeAt(0);
        current = _generator.reorderForTsp([...current, next], userLat, userLng);
      } else {
        break;
      }
    }
    return result;
  }
}
