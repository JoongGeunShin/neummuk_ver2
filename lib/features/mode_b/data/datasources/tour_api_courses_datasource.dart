import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/tourist_route_entity.dart';

class TourApiCoursesDatasource {
  static const _enabled = true;

  /// 현재 위치 반경 내 여행코스(contentTypeId=25) 조회.
  /// [weightKg]: 칼로리 추산에 사용. TourAPI는 코스 거리를 제공하지 않으므로
  /// 이동수단별 표준 거리(도보 5km / 자전거 15km)로 추정한다.
  Future<List<TouristRouteEntity>> fetchNearbyCourses({
    required double lat,
    required double lng,
    String transport = 'walk',
    double weightKg = AppConstants.defaultWeightKg,
    int radiusM = 3000,
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
      'contentTypeId': '25',
      'arrange': 'E',
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
          .map((item) => _parse(item, transport, weightKg))
          .whereType<TouristRouteEntity>()
          .toList();
    } catch (e) {
      debugPrint('[TourApi] fetchNearbyCourses error: $e');
      return [];
    }
  }

  /// TourAPI 코스(contentTypeId=25)에 대해 detailIntro2를 호출해
  /// 실제 거리·소요시간·kcal를 채운 새 엔티티를 반환한다.
  Future<TouristRouteEntity> enrichCourse(
    TouristRouteEntity base, {
    required double weightKg,
  }) async {
    // 두루누비 코스(id가 숫자)는 이미 상세 정보가 있으므로 그대로 반환
    if (!base.id.startsWith('tour_')) return base;

    final contentId = base.id.replaceFirst('tour_', '');
    final key = dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';
    if (key.isEmpty) return base;

    try {
      final uri =
          Uri.parse('${AppConstants.tourApiBaseUrl}/detailIntro2').replace(
        queryParameters: {
          'serviceKey': key,
          'MobileOS': 'ETC',
          'MobileApp': 'neummuk',
          'contentId': contentId,
          'contentTypeId': '25',
          '_type': 'json',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return base;
      if (res.body.trimLeft().startsWith('<')) return base;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final item = body['response']?['body']?['items']?['item'];
      if (item == null) return base;
      final m = item is List
          ? (item.isNotEmpty ? item[0] as Map<String, dynamic> : null)
          : item as Map<String, dynamic>;
      if (m == null) return base;

      final distKm = _parseDistanceKm(m['distance']?.toString());
      final durationMin = _parseTakeTimeToMinutes(m['taketime']?.toString());

      if (distKm <= 0 && durationMin <= 0) return base;

      final isBike = base.type == '자전거';
      final met = AppConstants.metValues[isBike ? 'bike' : 'walk']!;
      final effectiveDuration =
          durationMin > 0 ? durationMin : (distKm / (isBike ? 15.0 : 4.0) * 60).round();
      final kcal = (met * weightKg * (effectiveDuration / 60.0)).round();

      return base.copyWith(
        distanceKm: distKm > 0 ? distKm : null,
        durationMinutes: effectiveDuration > 0 ? effectiveDuration : null,
        kcal: kcal > 0 ? kcal : null,
        tags: const [], // 추정 태그 제거
      );
    } catch (e) {
      debugPrint('[TourApi.enrich] $contentId: $e');
      return base;
    }
  }

  static double _parseDistanceKm(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final s = raw.replaceAll(',', '').replaceAll(' ', '');
    final kmMatch = RegExp(r'([\d.]+)\s*km', caseSensitive: false).firstMatch(s);
    if (kmMatch != null) return double.tryParse(kmMatch.group(1)!) ?? 0;
    final mMatch = RegExp(r'([\d.]+)\s*m', caseSensitive: false).firstMatch(s);
    if (mMatch != null) return (double.tryParse(mMatch.group(1)!) ?? 0) / 1000;
    return double.tryParse(s) ?? 0;
  }

  static int _parseTakeTimeToMinutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    int minutes = 0;
    final h = RegExp(r'(\d+)\s*시간').firstMatch(raw);
    final m = RegExp(r'(\d+)\s*분').firstMatch(raw);
    if (h != null) minutes += int.parse(h.group(1)!) * 60;
    if (m != null) minutes += int.parse(m.group(1)!);
    return minutes;
  }

  TouristRouteEntity? _parse(
      Map<String, dynamic> item, String transport, double weightKg) {
    try {
      final id = 'tour_${item['contentid'] ?? ''}';
      final name = item['title']?.toString() ?? '';
      if (name.isEmpty) return null;

      final distFromUser =
          int.tryParse(item['dist']?.toString().split('.').first ?? '') ?? 0;

      final addr = item['addr1']?.toString() ?? '';
      final regionLabel =
          addr.isNotEmpty ? addr.split(' ').take(2).join(' ') : null;

      final mapx = double.tryParse(item['mapx']?.toString() ?? '');
      final mapy = double.tryParse(item['mapy']?.toString() ?? '');

      final img1 = item['firstimage']?.toString() ?? '';
      final img2 = item['firstimage2']?.toString() ?? '';
      final imageUrls = <String>[
        if (img1.isNotEmpty) img1,
        if (img2.isNotEmpty && img2 != img1) img2,
      ];

      // TourAPI는 코스 길이를 제공하지 않으므로 이동수단별 표준값으로 추정한다.
      // 도보: 5km / 75min, 자전거: 15km / 60min
      final isBike = transport == 'bike';
      final distKm = isBike ? 15.0 : 5.0;
      final durationMin = isBike ? 60 : 75;
      final met = AppConstants.metValues[isBike ? 'bike' : 'walk']!;
      final kcal = (met * weightKg * (durationMin / 60.0)).round();

      return TouristRouteEntity(
        id: id,
        name: name,
        distanceKm: distKm,
        durationMinutes: durationMin,
        kcal: kcal,
        type: isBike ? '자전거' : '도보',
        tags: const ['📍 추정'],
        region: regionLabel,
        distanceFromUserM: distFromUser,
        startLat: mapy,
        startLng: mapx,
        imageUrls: imageUrls,
        source: 'tour_api',
      );
    } catch (e) {
      debugPrint('[TourApi] parse error: $e');
      return null;
    }
  }
}
