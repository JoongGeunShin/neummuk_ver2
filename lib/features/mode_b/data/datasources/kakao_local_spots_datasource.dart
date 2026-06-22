import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/spot_entity.dart';

/// Kakao Local API 카테고리 검색
/// CT1: 문화시설, AT4: 관광명소
class KakaoLocalSpotsDatasource {
  Future<List<SpotEntity>> fetchSpots({
    required double lat,
    required double lng,
    required List<String> categoryGroupCodes,
    int radiusM = 3000,
    int size = 15,
  }) async {
    final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
    if (key.isEmpty || categoryGroupCodes.isEmpty) return [];

    final results = <SpotEntity>[];

    for (final code in categoryGroupCodes) {
      try {
        final uri =
            Uri.parse('${AppConstants.kakaoLocalBaseUrl}/search/category.json').replace(
          queryParameters: {
            'category_group_code': code,
            'x': '$lng',
            'y': '$lat',
            'radius': '$radiusM',
            'size': '$size',
            'sort': 'distance',
          },
        );

        final res = await http
            .get(uri, headers: {'Authorization': 'KakaoAK $key'})
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final docs = (data['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        for (final doc in docs) {
          final id = doc['id']?.toString() ?? '';
          final name = doc['place_name']?.toString() ?? '';
          final x = double.tryParse(doc['x']?.toString() ?? '');
          final y = double.tryParse(doc['y']?.toString() ?? '');
          if (name.isEmpty || x == null || y == null) continue;

          final dist = int.tryParse(doc['distance']?.toString() ?? '') ?? 0;

          final phone = doc['phone']?.toString() ?? '';
          final placeUrl = doc['place_url']?.toString() ?? '';

          results.add(SpotEntity(
            id: 'kakao_${code}_$id',
            name: name,
            lat: y,
            lng: x,
            type: code == 'AT4' ? 'tourist_sight' : 'culture',
            source: 'kakao',
            category: doc['category_name']?.toString(),
            address: (doc['road_address_name']?.toString() ?? '').isNotEmpty
                ? doc['road_address_name']?.toString()
                : doc['address_name']?.toString(),
            distanceFromUserM: dist,
            tel: phone.isNotEmpty ? phone : null,
            placeUrl: placeUrl.isNotEmpty ? placeUrl : null,
          ));
        }
      } catch (e) {
        debugPrint('[KakaoSpots] code=$code error: $e');
      }
    }

    return results;
  }
}
