import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/tourist_route_entity.dart';

class TourApiCoursesDatasource {
  /// 공공데이터포털 KorService2_GW 활용신청 승인 후 true로 변경.
  static const _enabled = true;

  /// 현재 위치 반경 내 여행코스(contentTypeId=25) 조회.
  /// arrange=E(거리순)이므로 반환 리스트는 가까운 순 정렬됨.
  Future<List<TouristRouteEntity>> fetchNearbyCourses({
    required double lat,
    required double lng,
    String transport = 'walk',
    int radiusM = 15000,
    int numOfRows = 20,
  }) async {
    if (!_enabled) {
      debugPrint('[TourApi] disabled');
      return [];
    }

    final key = dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('[TourApi] TOUR_API_SERVICE_KEY not set');
      return [];
    }

    final uri = Uri.parse('${AppConstants.tourApiBaseUrl}/locationBasedList2')
        .replace(queryParameters: {
      'serviceKey': key,
      'numOfRows': '$numOfRows',
      'pageNo': '1',
      'MobileOS': 'ETC',
      'MobileApp': 'neummuk',
      'mapX': '$lng',
      'mapY': '$lat',
      'radius': '$radiusM',
      'contentTypeId': '25', // 여행코스
      'arrange': 'E', // 거리순
      '_type': 'json',
    });

    try {
      debugPrint('[TourApi] url=$uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[TourApi] HTTP ${res.statusCode}');

      if (res.statusCode != 200) {
        debugPrint('[TourApi] error body: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
        return [];
      }
      if (res.body.trimLeft().startsWith('<')) {
        debugPrint('[TourApi] XML error: ${res.body.substring(0, 300)}');
        return [];
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final header = body['response']?['header'];
      debugPrint('[TourApi] resultCode=${header?['resultCode']}');

      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) {
        debugPrint('[TourApi] no items near ($lat, $lng) radius=${radiusM}m');
        return [];
      }

      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [Map<String, dynamic>.from(raw as Map)];

      debugPrint('[TourApi] ${list.length} courses found');

      return list
          .map((item) => _parse(item, transport))
          .whereType<TouristRouteEntity>()
          .toList();
    } catch (e) {
      debugPrint('[TourApi] fetchNearbyCourses error: $e');
      return [];
    }
  }

  TouristRouteEntity? _parse(Map<String, dynamic> item, String transport) {
    try {
      final id = 'tour_${item['contentid'] ?? ''}';
      final name = item['title']?.toString() ?? '';
      if (name.isEmpty) return null;

      final distFromUser =
          int.tryParse(item['dist']?.toString().split('.').first ?? '') ?? 0;

      // 주소에서 시군구 추출
      final addr = item['addr1']?.toString() ?? '';
      final regionLabel = addr.isNotEmpty
          ? addr.split(' ').take(2).join(' ')
          : null;

      // mapX = 경도(lng), mapY = 위도(lat) — TourAPI 컨벤션
      final mapx = double.tryParse(item['mapx']?.toString() ?? '');
      final mapy = double.tryParse(item['mapy']?.toString() ?? '');

      // 대표 이미지 (firstimage > firstimage2 순서로 fallback)
      final img1 = item['firstimage']?.toString() ?? '';
      final img2 = item['firstimage2']?.toString() ?? '';
      final imageUrls = <String>[
        if (img1.isNotEmpty) img1,
        if (img2.isNotEmpty && img2 != img1) img2,
      ];

      return TouristRouteEntity(
        id: id,
        name: name,
        distanceKm: 0,
        durationMinutes: 0,
        kcal: 0,
        type: transport == 'bike' ? '자전거' : '도보',
        tags: const [],
        region: regionLabel,
        distanceFromUserM: distFromUser,
        startLat: mapy,
        startLng: mapx,
        imageUrls: imageUrls,
      );
    } catch (e) {
      debugPrint('[TourApi] parse error: $e');
      return null;
    }
  }
}
