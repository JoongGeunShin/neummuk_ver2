import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/spot_entity.dart';

/// TourAPI 개별 스팟 검색
/// contentTypeId: 12(관광지), 14(문화시설), 15(행사/공연/축제), 28(레포츠), 38(쇼핑)
class TourApiSpotsDatasource {
  Future<List<SpotEntity>> fetchSpots({
    required double lat,
    required double lng,
    required List<int> contentTypeIds,
    int radiusM = 3000,
    int numOfRows = 15,
  }) async {
    final key = dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';
    if (key.isEmpty || contentTypeIds.isEmpty) return [];

    final perType = await Future.wait(contentTypeIds.map((typeId) => _fetchOneType(
          key: key,
          typeId: typeId,
          lat: lat,
          lng: lng,
          radiusM: radiusM,
          numOfRows: numOfRows,
        )));

    return perType.expand((spots) => spots).toList();
  }

  Future<List<SpotEntity>> _fetchOneType({
    required String key,
    required int typeId,
    required double lat,
    required double lng,
    required int radiusM,
    required int numOfRows,
  }) async {
    final results = <SpotEntity>[];
    try {
      final uri =
          Uri.parse('${AppConstants.tourApiBaseUrl}/locationBasedList2').replace(
        queryParameters: {
          'serviceKey': key,
          'numOfRows': '$numOfRows',
          'pageNo': '1',
          'MobileOS': 'ETC',
          'MobileApp': 'neummuk',
          'mapX': '$lng',
          'mapY': '$lat',
          'radius': '$radiusM',
          'contentTypeId': '$typeId',
          'arrange': 'E',
          '_type': 'json',
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return results;
      if (res.body.trimLeft().startsWith('<')) return results;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = body['response']?['body']?['items'];
      // 검색 결과 0건이면 TourAPI가 items를 "" (빈 문자열)로 내려줌 — Map일 때만 인덱싱
      if (items is! Map) return results;
      final raw = items['item'];
      if (raw == null) return results;

      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [Map<String, dynamic>.from(raw as Map)];

      for (final item in list) {
        final id = item['contentid']?.toString() ?? '';
        final name = item['title']?.toString() ?? '';
        final mapx = double.tryParse(item['mapx']?.toString() ?? '');
        final mapy = double.tryParse(item['mapy']?.toString() ?? '');
        if (name.isEmpty || mapx == null || mapy == null) continue;

        final dist =
            int.tryParse(item['dist']?.toString().split('.').first ?? '') ?? 0;
        final addr = item['addr1']?.toString() ?? '';
        final img = item['firstimage']?.toString() ?? '';

        results.add(SpotEntity(
          id: 'tour_${typeId}_$id',
          name: name,
          lat: mapy,
          lng: mapx,
          type: _typeFromId(typeId),
          source: 'tour_api',
          category: _categoryLabel(typeId),
          address: addr.isEmpty ? null : addr,
          imageUrl: img.isEmpty ? null : img,
          distanceFromUserM: dist,
        ));
      }
    } catch (e) {
      debugPrint('[TourApiSpots] typeId=$typeId error: $e');
    }
    return results;
  }

  String _typeFromId(int typeId) => switch (typeId) {
        12 => 'tourist_sight',
        14 => 'culture',
        15 => 'event',
        28 => 'sports',
        38 => 'shopping',
        _ => 'etc',
      };

  String _categoryLabel(int typeId) => switch (typeId) {
        12 => '관광지',
        14 => '문화시설',
        15 => '행사/공연/축제',
        28 => '레포츠',
        38 => '쇼핑',
        _ => '기타',
      };
}
