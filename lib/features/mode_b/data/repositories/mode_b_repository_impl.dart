import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../explore/domain/repositories/food_catalog_repository.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';
import '../datasources/durunubi_datasource.dart';
import '../datasources/tour_api_courses_datasource.dart';

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

  @override
  Future<List<FoodEntity>> getFoods({String? query, String? category}) async {
    final resolvedCategory = (category == null || category == '전체') ? null : category;
    final results = (query == null || query.trim().isEmpty)
        ? await _foodCatalogRepo.getPopularFoods(
            category: resolvedCategory,
            limit: 30,
          )
        : await _foodCatalogRepo.searchFoods(
            query.trim(),
            category: resolvedCategory,
          );
    return results
        .map((c) => FoodEntity.fromCatalog(c, weightKg: _weightKg))
        .toList();
  }

  @override
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
  }) async {
    final results = await Future.wait([
      _tourApi.fetchNearbyCourses(
        lat: latitude,
        lng: longitude,
        transport: transport,
        weightKg: _weightKg,
      ),
      _fetchDurunubiRoutes(latitude, longitude, transport),
    ]);

    final tourApiRoutes = results[0];
    final durunubiRoutes = results[1];

    debugPrint('[ModeBRepo] TourAPI=${tourApiRoutes.length}, Durunubi=${durunubiRoutes.length}');

    final merged = [...durunubiRoutes, ...tourApiRoutes];

    if (merged.isEmpty) return [];

    // 현재 위치에서 가까운 순 ASC 정렬
    merged.sort((a, b) =>
        _distanceFromUser(a, latitude, longitude)
            .compareTo(_distanceFromUser(b, latitude, longitude)));

    return merged;
  }

  Future<List<TouristRouteEntity>> _fetchDurunubiRoutes(
    double lat,
    double lng,
    String transport,
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

    if (region == null) return all;

    final local = all.where((r) => _matchesRegion(r.region, region)).toList();
    debugPrint('[Durunubi] local (${region.sido} ${region.sigungu}): ${local.length}');

    final localMarked = local.map((r) => r.copyWith(isLocal: true)).toList();
    final national = all.where((r) => !local.contains(r)).toList();
    return [...localMarked, ...national];
  }

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

  bool _matchesRegion(
    String? routeSigun,
    ({String sido, String sigungu}) region,
  ) {
    if (routeSigun == null || routeSigun.isEmpty) return false;
    final sidoShort = region.sido.replaceAll(RegExp(r'(특별시|광역시|특별자치시|도|특별자치도)'), '');
    return routeSigun.contains(region.sido) ||
        routeSigun.contains(sidoShort) ||
        (region.sigungu.isNotEmpty && routeSigun.contains(region.sigungu));
  }

  TouristRouteEntity? _parseDurunubi(
    Map<String, dynamic> item,
    double met,
    String transport,
  ) {
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
        imageUrls: imageUrls,
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

  @override
  Future<List<TouristRouteEntity>> enrichBatch(List<TouristRouteEntity> batch) async {
    // TourAPI 코스만 병렬 enrichment, 나머지는 그대로
    final futures = batch.map((r) => r.id.startsWith('tour_')
        ? _tourApi.enrichCourse(r, weightKg: _weightKg)
        : Future.value(r));
    return Future.wait(futures);
  }

  int _distanceFromUser(TouristRouteEntity r, double userLat, double userLng) {
    if (r.distanceFromUserM != null) return r.distanceFromUserM!;
    if (r.startLat != null && r.startLng != null) {
      return _haversineM(userLat, userLng, r.startLat!, r.startLng!);
    }
    return 99999999;
  }

  int _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(dLambda / 2) * math.sin(dLambda / 2);
    return (R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))).round();
  }
}
