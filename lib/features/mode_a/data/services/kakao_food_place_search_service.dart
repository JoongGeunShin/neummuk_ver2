import 'dart:convert';
import 'dart:math' show max;

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../explore/domain/entities/food_catalog_entity.dart';
import '../../domain/entities/restaurant_entity.dart';

/// food_catalog(Firestore) 음식 하나를 키워드로 Kakao Local(FD6)에서 실제 매장을
/// 찾는 로직. Mode A(getNearbyRestaurants)와 mode_match(오늘의 맞춤 맛집)가 공유한다.
///
/// 반환되는 RestaurantEntity의 kcal/menu/category는 매장 자체 정보가 아니라 검색에
/// 쓰인 food_catalog 음식의 실측값 — "이 매장에서 이 칼로리대 음식을 판다"는 매칭
/// 근거를 그대로 보여주기 위함.
class KakaoFoodPlaceSearchService {
  KakaoFoodPlaceSearchService._();

  static Future<List<RestaurantEntity>> byKeyword({
    required FoodCatalogEntity food,
    required double lat,
    required double lng,
    required int radiusM,
    required String kakaoKey,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${AppConstants.kakaoLocalBaseUrl}/search/keyword.json',
          ).replace(
            queryParameters: {
              'query': food.displayName,
              'category_group_code': 'FD6',
              'x': lng.toString(),
              'y': lat.toString(),
              'radius': radiusM.clamp(100, 20000).toString(),
              'size': '5',
              'sort': 'distance',
            },
          ),
          headers: {'Authorization': 'KakaoAK $kakaoKey'},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['documents'] as List? ?? [];
    final kcal = food.nutrition.caloriesKcal.round();

    return docs
        .map<RestaurantEntity?>((doc) {
          final x = double.tryParse(doc['x']?.toString() ?? '');
          final y = double.tryParse(doc['y']?.toString() ?? '');
          if (x == null || y == null || x == 0 || y == 0) return null;
          final name = (doc['place_name'] as String? ?? '').trim();
          if (name.isEmpty) return null;

          final categoryName = doc['category_name'] as String? ?? '';
          final distanceM =
              int.tryParse(doc['distance']?.toString() ?? '0') ?? 0;

          return RestaurantEntity(
            id: 'kakao_${doc['id']}',
            name: name,
            menu: food.displayName,
            category: food.category,
            kcal: kcal,
            distanceM: distanceM,
            walkMinutes: max(1, (distanceM / 80).ceil()), // 도보 ~80m/분
            rating: 0.0,
            reviewCount: 0,
            latitude: y,
            longitude: x,
            kind: isKindCafe(categoryName) ? 'cafe' : 'food',
            imageType: imageTypeFromCategory(categoryName),
            address: (doc['road_address_name'] as String? ?? '').isNotEmpty
                ? doc['road_address_name'] as String
                : doc['address_name'] as String?,
            tel: doc['phone'] as String?,
            kakaoPlaceId: doc['id'] as String?,
          );
        })
        .whereType<RestaurantEntity>()
        .toList();
  }

  static bool isKindCafe(String categoryName) {
    final lower = categoryName.toLowerCase();
    return lower.contains('카페') ||
        lower.contains('커피') ||
        lower.contains('디저트') ||
        lower.contains('베이커리');
  }

  static String imageTypeFromCategory(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('카페') || lower.contains('커피')) return 'cafe';
    if (lower.contains('일식') || lower.contains('초밥') || lower.contains('스시')) {
      return 'sushi';
    }
    if (lower.contains('삼겹') || lower.contains('갈비') || lower.contains('고기')) {
      return 'pork2';
    }
    if (lower.contains('돈까스') || lower.contains('경양식')) return 'pork';
    if (lower.contains('국밥') || lower.contains('수제비') || lower.contains('탕')) {
      return 'soup';
    }
    if (lower.contains('김밥') || lower.contains('분식')) return 'kimbap';
    if (lower.contains('국수') || lower.contains('냉면') || lower.contains('칼국수')) {
      return 'noodle';
    }
    return 'generic';
  }
}
