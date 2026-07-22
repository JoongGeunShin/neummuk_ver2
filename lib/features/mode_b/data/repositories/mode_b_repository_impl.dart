import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../explore/domain/repositories/food_catalog_repository.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';
import '../../domain/services/mode_b_course_generator.dart';
import '../datasources/durunubi_datasource.dart';
import '../datasources/kakao_local_spots_datasource.dart';
import '../datasources/tmap_route_datasource.dart';
import '../datasources/tour_api_courses_datasource.dart';
import '../datasources/tour_api_spots_datasource.dart';

class ModeBRepositoryImpl implements ModeBRepository {
  ModeBRepositoryImpl({
    required FoodCatalogRepository foodCatalogRepo,
    required double weightKg,
  })  : _foodCatalogRepo = foodCatalogRepo,
        _weightKg = weightKg;

  final FoodCatalogRepository _foodCatalogRepo;
  final double _weightKg;
  final _durunubi = DurunubiDatasource();
  final _tourApi = TourApiCoursesDatasource();
  final _kakaoSpots = KakaoLocalSpotsDatasource();
  final _tourApiSpots = TourApiSpotsDatasource();
  final _generator = const ModeBCourseGenerator();
  final _tmapRoute = TmapRouteDatasource();

  // ── 음식 검색 ────────────────────────────────────────────────────

  @override
  Future<List<FoodEntity>> getFoods({String? query, String? category}) async {
    final resolvedCategory = (category == null || category == '전체') ? null : category;
    final results = (query == null || query.trim().isEmpty)
        ? await _foodCatalogRepo.getPopularFoods(category: resolvedCategory, limit: 30)
        : await _foodCatalogRepo.searchFoods(query.trim(), category: resolvedCategory);
    return results.map((c) => FoodEntity.fromCatalog(c, weightKg: _weightKg)).toList();
  }

  // ── 기성 코스 검색 (두루누비 + TourAPI 여행코스) ───────────────────

  @override
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
    int radiusM = 3000,
  }) async {
    final results = await Future.wait([
      _tourApi.fetchNearbyCourses(
        lat: latitude,
        lng: longitude,
        transport: transport,
        weightKg: _weightKg,
        radiusM: radiusM,
      ),
      _fetchDurunubiRoutes(latitude, longitude, transport, radiusM),
    ]);

    final tourApiRoutes = results[0];
    final durunubiRoutes = results[1];

    debugPrint('[ModeBRepo] TourAPI=${tourApiRoutes.length}, Durunubi=${durunubiRoutes.length}');

    final merged = [...durunubiRoutes, ...tourApiRoutes];
    if (merged.isEmpty) return [];

    // 칼로리 ±20% 필터 (우선 적용)
    final tolerance = AppConstants.kcalMatchTolerancePct;
    final matched = merged.where((r) {
      if (r.kcal <= 0) return true; // kcal 미상 → 포함
      return (r.kcal - targetKcal).abs() <= targetKcal * tolerance;
    }).toList();

    // 매칭 결과가 너무 적으면 전체를 kcal 근사 순으로 정렬해서 반환
    final base = matched.length >= 3 ? matched : merged;
    base.sort((a, b) {
      final aDiff = (a.kcal - targetKcal).abs();
      final bDiff = (b.kcal - targetKcal).abs();
      if (aDiff != bDiff) return aDiff.compareTo(bDiff);
      return _distanceFromUser(a, latitude, longitude)
          .compareTo(_distanceFromUser(b, latitude, longitude));
    });

    return base;
  }

  Future<List<TouristRouteEntity>> _fetchDurunubiRoutes(
    double lat,
    double lng,
    String transport,
    int radiusM,
  ) async {
    final region = await _reverseGeocode(lat, lng);
    final items = await _durunubi.fetchAllCoursesCached();
    if (items.isEmpty) return [];

    final met = transport == 'bike'
        ? AppConstants.metValues['bike']!
        : AppConstants.metValues['walk']!;

    final all = items
        .map((item) => _parseDurunubi(item, met, transport))
        .whereType<TouristRouteEntity>()
        .toList();

    debugPrint('[Durunubi] parsed ${all.length}/${items.length}');

    // 좌표 없는 코스 제외 + 반경 필터
    // 두루누비 코스에 좌표가 없으면 반경 기준을 알 수 없으므로 제외한다
    final radiusKm = radiusM / 1000.0;
    final inRadius = all.where((r) {
      if (!r.hasCoordinate) return false;
      return haversineDistanceKm(lat, lng, r.startLat!, r.startLng!) <= radiusKm;
    }).toList();

    debugPrint('[Durunubi] inRadius (${radiusKm.toStringAsFixed(1)}km): ${inRadius.length}/${all.length}');

    if (region == null) return inRadius;

    // 반경 내 코스 중 현재 지역은 "내 지역" 태그 표시
    final local = inRadius.where((r) => _matchesRegion(r.region, region)).toList();
    final localMarked = local.map((r) => r.copyWith(isLocal: true)).toList();
    final others = inRadius.where((r) => !local.contains(r)).toList();
    return [...localMarked, ...others];
  }

  // ── 스팟 검색 ────────────────────────────────────────────────────

  @override
  Future<List<SpotEntity>> searchSpots({
    required double latitude,
    required double longitude,
    required Set<SpotTag> tags,
    required String transport,
  }) async {
    final radiusM =
        transport == 'bike' ? AppConstants.modeBBikeRadiusM : AppConstants.modeBWalkRadiusM;
    final effectiveTags = tags.isEmpty ? SpotTag.values.toSet() : tags;

    // 카카오 로컬 카테고리 코드 수집 (우선순위 높음)
    final kakaoCodes = <String>{};
    for (final tag in effectiveTags) {
      kakaoCodes.addAll(tag.kakaoGroupCodes);
    }

    // TourAPI contentTypeId 수집 (카카오가 지원하지 않는 타입 포함)
    final tourTypeIds = <int>[];
    for (final tag in effectiveTags) {
      final typeId = tag.tourApiContentTypeId;
      if (typeId != null) tourTypeIds.add(typeId);
    }

    final results = await Future.wait([
      if (kakaoCodes.isNotEmpty)
        _kakaoSpots.fetchSpots(
          lat: latitude,
          lng: longitude,
          categoryGroupCodes: kakaoCodes.toList(),
          radiusM: radiusM,
        )
      else
        Future.value(<SpotEntity>[]),
      if (tourTypeIds.isNotEmpty)
        _tourApiSpots.fetchSpots(
          lat: latitude,
          lng: longitude,
          contentTypeIds: tourTypeIds,
          radiusM: radiusM,
        )
      else
        Future.value(<SpotEntity>[]),
    ]);

    final kakaoSpots = results[0];
    final tourSpots = results[1];

    // 중복 제거: 같은 이름+좌표 근처(50m 이내)는 카카오 우선
    final combined = <SpotEntity>[...kakaoSpots];
    for (final ts in tourSpots) {
      final isDuplicate = kakaoSpots.any((ks) =>
          haversineDistanceKm(ks.lat, ks.lng, ts.lat, ts.lng) < 0.05 &&
          ks.name == ts.name);
      if (!isDuplicate) combined.add(ts);
    }

    combined.sort((a, b) =>
        (a.distanceFromUserM ?? 99999).compareTo(b.distanceFromUserM ?? 99999));

    debugPrint('[ModeBRepo] spots: kakao=${kakaoSpots.length}, tourApi=${tourSpots.length}, combined=${combined.length}');
    return combined;
  }

  // ── 코스 생성 ────────────────────────────────────────────────────

  @override
  Future<TouristRouteEntity?> generateCourse({
    required List<SpotEntity> spots,
    required double userLat,
    required double userLng,
    required int targetKcal,
    required String transport,
    List<SpotEntity> mandatorySpots = const [],
    bool forceAll = false,
  }) async {
    final picked = _generator.select(
      spots: spots,
      userLat: userLat,
      userLng: userLng,
      targetKcal: targetKcal,
      transport: transport,
      weightKg: _weightKg,
      mandatorySpots: mandatorySpots,
      forceAll: forceAll,
    );
    if (picked.selected.isEmpty) return null;

    // 실거리 보정이 스팟 구성을 건드려도 되는 범위:
    // - 제거: forceAll(카트 전체 고정)이 아닐 때만, mandatory 구간은 보존
    // - 추가+재정렬: 순수 자동선택(mandatory 없음)일 때만 — mandatory-먼저 순서를 흐트러뜨리지 않기 위함
    final canRemove = !forceAll;
    final canAdd = picked.mandatoryCount == 0 && !forceAll;
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
        weightKg: _weightKg,
        actualDistKmOverride: realDistKm,
      );
      if (result == null) return null;

      final diff = result.kcal - targetKcal;
      if (i == maxCorrections || diff.abs() <= tolerance) break;

      if (diff > 0 && canRemove && current.length > picked.mandatoryCount && current.length > 1) {
        // 칼로리 초과 → 가장 마지막에 방문하는(가장 먼) 자동보충 스팟 제거
        current = current.sublist(0, current.length - 1);
      } else if (diff < 0 && canAdd && pool.isNotEmpty) {
        // 칼로리 부족 → 다음 후보 추가 후 TSP 재정렬
        final next = pool.removeAt(0);
        current = _generator.reorderForTsp([...current, next], userLat, userLng);
      } else {
        break;
      }
    }

    return result;
  }

  // ── Enrichment ────────────────────────────────────────────────────

  @override
  Future<List<TouristRouteEntity>> enrichBatch(List<TouristRouteEntity> batch) async {
    final futures = batch.map((r) => r.id.startsWith('tour_')
        ? _tourApi.enrichCourse(r, weightKg: _weightKg)
        : Future.value(r));
    return Future.wait(futures);
  }

  // ── 역지오코딩 ────────────────────────────────────────────────────

  Future<({String sido, String sigungu})?> _reverseGeocode(double lat, double lng) async {
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return null;
      final uri = Uri.parse('https://dapi.kakao.com/v2/local/geo/coord2regioncode.json')
          .replace(queryParameters: {'x': '$lng', 'y': '$lat'});
      final res = await http
          .get(uri, headers: {'Authorization': 'KakaoAK $key'})
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>?;
      if (docs == null || docs.isEmpty) return null;
      final doc = (docs.firstWhere(
            (d) => d['region_type'] == 'H',
            orElse: () => docs.first,
          ) as Map<String, dynamic>);
      return (
        sido: doc['region_1depth_name']?.toString() ?? '',
        sigungu: doc['region_2depth_name']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('[ModeBRepo] reverseGeocode error: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  bool _matchesRegion(String? routeSigun, ({String sido, String sigungu}) region) {
    if (routeSigun == null || routeSigun.isEmpty) return false;
    final sidoShort = region.sido.replaceAll(RegExp(r'(특별시|광역시|특별자치시|도|특별자치도)'), '');
    return routeSigun.contains(region.sido) ||
        routeSigun.contains(sidoShort) ||
        (region.sigungu.isNotEmpty && routeSigun.contains(region.sigungu));
  }

  TouristRouteEntity? _parseDurunubi(Map<String, dynamic> item, double met, String transport) {
    try {
      final id = item['crsIdx']?.toString() ?? '';
      final name = item['crsKorNm']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) return null;

      final distKm = double.tryParse(item['crsDstnc']?.toString() ?? '') ?? 0.0;
      final totMin = double.tryParse(item['crsTotlRqrmHour']?.toString() ?? '') ?? 0.0;
      if (totMin <= 0) return null;

      final kcal = (met * _weightKg * (totMin / 60.0)).round();
      final level = item['crsLevel']?.toString() ?? '';
      final sigun = item['sigun']?.toString() ?? '';
      final gpxpath = item['gpxpath']?.toString();

      final imageUrls = <String>[];
      for (final key in ['thumbImg', 'imgUrl', 'crsImgFileNm', 'repFileNm']) {
        final v = item[key]?.toString() ?? '';
        if (v.isNotEmpty && v.startsWith('http')) {
          imageUrls.add(v);
          break;
        }
      }

      // 두루누비 API 좌표 필드: lat/lng (공식), mapY/mapX (일부 응답), 없으면 null
      final lat = double.tryParse(item['lat']?.toString() ?? '') ??
          double.tryParse(item['mapY']?.toString() ?? '') ??
          double.tryParse(item['mapy']?.toString() ?? '');
      final lng = double.tryParse(item['lng']?.toString() ?? '') ??
          double.tryParse(item['mapX']?.toString() ?? '') ??
          double.tryParse(item['mapx']?.toString() ?? '');

      return TouristRouteEntity(
        id: id,
        name: name,
        distanceKm: distKm,
        durationMinutes: totMin.round(),
        kcal: kcal,
        type: transport == 'bike' ? '자전거' : '도보',
        tags: [if (level.isNotEmpty) _levelTag(level)],
        region: sigun.isEmpty ? null : sigun,
        gpxpath: (gpxpath != null && gpxpath.isNotEmpty) ? gpxpath : null,
        startLat: lat,
        startLng: lng,
        imageUrls: imageUrls,
        source: 'durunubi',
      );
    } catch (e) {
      debugPrint('[Durunubi] parse error: $e');
      return null;
    }
  }

  String _levelTag(String level) => switch (level) {
        '1' || '하' => '🟢 쉬움',
        '2' || '중하' => '🟡 보통',
        '3' || '중' => '🟡 보통',
        '4' || '중상' => '🔴 어려움',
        '5' || '상' => '🔴 어려움',
        _ => level,
      };

  int _distanceFromUser(TouristRouteEntity r, double userLat, double userLng) {
    if (r.distanceFromUserM != null) return r.distanceFromUserM!;
    if (r.startLat != null && r.startLng != null) {
      return (haversineDistanceKm(userLat, userLng, r.startLat!, r.startLng!) * 1000).round();
    }
    return 99999999;
  }

}
