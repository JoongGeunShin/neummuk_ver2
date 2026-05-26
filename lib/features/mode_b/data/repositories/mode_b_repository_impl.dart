import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/entities/tourist_route_entity.dart';
import '../../domain/repositories/mode_b_repository.dart';
import '../datasources/durunubi_datasource.dart';
import '../datasources/tour_api_courses_datasource.dart';

const _mockFoods = [
  FoodEntity(id:'f1', name:'삼겹살', kcal:620, category:'한식', emoji:'🥓', walkMinutes:89, bikeMinutes:47),
  FoodEntity(id:'f2', name:'평양냉면', kcal:480, category:'한식', emoji:'🍜', walkMinutes:69, bikeMinutes:36),
  FoodEntity(id:'f3', name:'비빔밥', kcal:580, category:'한식', emoji:'🍱', walkMinutes:83, bikeMinutes:44),
  FoodEntity(id:'f4', name:'떡볶이', kcal:420, category:'분식', emoji:'🌶️', walkMinutes:60, bikeMinutes:32),
  FoodEntity(id:'f5', name:'치킨 한마리', kcal:1200, category:'한식', emoji:'🍗', walkMinutes:172, bikeMinutes:90),
  FoodEntity(id:'f6', name:'김밥', kcal:320, category:'분식', emoji:'🍙', walkMinutes:46, bikeMinutes:24),
  FoodEntity(id:'f7', name:'짜장면', kcal:700, category:'중식', emoji:'🍜', walkMinutes:100, bikeMinutes:53),
  FoodEntity(id:'f8', name:'칼국수', kcal:520, category:'한식', emoji:'🍲', walkMinutes:74, bikeMinutes:39),
  FoodEntity(id:'f9', name:'돈까스', kcal:720, category:'경양식', emoji:'🍱', walkMinutes:103, bikeMinutes:54),
  FoodEntity(id:'f10', name:'아메리카노', kcal:10, category:'카페', emoji:'☕', walkMinutes:1, bikeMinutes:1),
  FoodEntity(id:'f11', name:'크로플', kcal:380, category:'디저트', emoji:'🧇', walkMinutes:54, bikeMinutes:29),
  FoodEntity(id:'f12', name:'김치찌개', kcal:450, category:'한식', emoji:'🍲', walkMinutes:64, bikeMinutes:34),
];

const mockRoutes = [
  TouristRouteEntity(id:'t1', name:'남산 둘레길 코스', distanceKm:4.2, durationMinutes:55, kcal:308, type:'도보', tags:['🌳 숲길']),
  TouristRouteEntity(id:'t2', name:'청계천 산책 루트', distanceKm:3.6, durationMinutes:48, kcal:268, type:'도보', tags:['💧 도심하천']),
  TouristRouteEntity(id:'t3', name:'북촌 한옥마을 코스', distanceKm:2.8, durationMinutes:38, kcal:212, type:'도보', tags:['🏯 전통']),
  TouristRouteEntity(id:'t4', name:'한강공원 자전거', distanceKm:8.5, durationMinutes:30, kcal:240, type:'자전거', tags:['🚲 야경']),
];

class ModeBRepositoryImpl implements ModeBRepository {
  final _durunubi = DurunubiDatasource();
  final _tourApi = TourApiCoursesDatasource();

  @override
  Future<List<FoodEntity>> getFoods({String? query, String? category}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockFoods.where((f) {
      if (category != null && category != '전체' && f.category != category) return false;
      if (query != null && query.isNotEmpty && !f.name.contains(query)) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<TouristRouteEntity>> getTouristRoutes({
    required double latitude,
    required double longitude,
    required int targetKcal,
    required String transport,
  }) async {
    // TourAPI(위치 기반) + 두루누비(전국 캐시) 병렬 조회
    final results = await Future.wait([
      _tourApi.fetchNearbyCourses(lat: latitude, lng: longitude, transport: transport),
      _fetchDurunubiRoutes(latitude, longitude, transport),
    ]);

    final tourApiRoutes = results[0]; // 이미 거리순 정렬
    final durunubiRoutes = results[1]; // 지역 코스 먼저, 전국 코스 뒤

    debugPrint('[ModeBRepo] TourAPI=${tourApiRoutes.length}, Durunubi=${durunubiRoutes.length}');

    // TourAPI 결과가 있으면 앞에, 두루누비는 보조
    final merged = [
      ...tourApiRoutes.take(10),
      ...durunubiRoutes.take(10),
    ];

    if (merged.isEmpty) {
      return mockRoutes
          .where((r) => r.type == (transport == 'bike' ? '자전거' : '도보'))
          .toList();
    }

    return merged;
  }

  // 두루누비: 지역 코스 먼저, 전국 코스 뒤
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

    List<TouristRouteEntity> local = [];
    if (region != null) {
      local = all.where((r) => _matchesRegion(r.region, region)).toList();
      debugPrint('[Durunubi] local (${region.sido} ${region.sigungu}): ${local.length}');
    }

    final localMarked = local.map((r) => r.copyWith(isLocal: true)).toList();
    final national = all.where((r) => !local.contains(r)).toList();

    return [...localMarked, ...national];
  }

  Future<({String sido, String sigungu})?> _reverseGeocode(
      double lat, double lng) async {
    try {
      final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (key.isEmpty) return null;

      final uri = Uri.parse(
              'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json')
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
    final sidoShort =
        region.sido.replaceAll(RegExp(r'(특별시|광역시|특별자치시|도|특별자치도)'), '');
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

      final distKm =
          double.tryParse(item['crsDstnc']?.toString() ?? '') ?? 0.0;
      final totMin =
          double.tryParse(item['crsTotlRqrmHour']?.toString() ?? '') ?? 0.0;
      if (totMin <= 0) return null;

      final kcal =
          (met * AppConstants.defaultWeightKg * (totMin / 60.0)).round();
      final level = item['crsLevel']?.toString() ?? '';
      final sigun = item['sigun']?.toString() ?? '';
      final gpxpath = item['gpxpath']?.toString();

      // 두루누비 이미지 필드 (API 응답에 있는 경우 파싱)
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
}
