import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';

/// 식품의약품안전처 식품영양성분 DB API (FoodNtrIrdntInfoService1) 호출.
///
/// AMT_NUM 필드 매핑:
///   AMT_NUM1  → 열량 (kcal)
///   AMT_NUM3  → 단백질 (g)
///   AMT_NUM4  → 지방 (g)
///   AMT_NUM6  → 탄수화물 (g)
///   AMT_NUM12 → 나트륨 (mg)
///   AMT_NUM22 → 포화지방산 (g)
///   AMT_NUM24 → 당류 (g)
class FoodApiDatasource {
  static const _timeout = Duration(seconds: 10);

  Future<List<FoodApiItem>> search(String foodName, {int numOfRows = 10}) async {
    if (AppEnv.foodApiKey.isEmpty) return [];

    final uri = Uri.parse(
      '${AppConstants.foodApiBaseUrl}/${AppConstants.foodApiEndpoint}',
    ).replace(queryParameters: {
      'serviceKey': AppEnv.foodApiKey,
      'pageNo': '1',
      'numOfRows': numOfRows.toString(),
      'FOOD_NM_KR': foodName,
      'type': 'json',
    });

    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return [];
      return _parse(res.body);
    } catch (_) {
      return [];
    }
  }

  List<FoodApiItem> _parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      // 응답 구조가 기관마다 다름 — response.body or body 두 경우 모두 처리
      final bodyMap = (json['response'] as Map<String, dynamic>?)?['body']
              as Map<String, dynamic>? ??
          json['body'] as Map<String, dynamic>? ??
          {};

      final rawItems = bodyMap['items'];
      List<dynamic> itemList = [];
      if (rawItems is List) {
        itemList = rawItems;
      } else if (rawItems is Map) {
        final inner = rawItems['item'];
        if (inner is List) itemList = inner;
        if (inner is Map) itemList = [inner];
      }

      return itemList
          .whereType<Map<String, dynamic>>()
          .map(FoodApiItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class FoodApiItem {
  const FoodApiItem({
    required this.foodCd,
    required this.foodName,
    required this.servingSizeG,
    required this.caloriesKcal,
    required this.carbsG,
    required this.sugarG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    this.saturatedFatG,
    this.cholesterolMg,
  });

  final String foodCd;
  final String foodName;
  final double servingSizeG;
  final double caloriesKcal;
  final double carbsG;
  final double sugarG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double? saturatedFatG;
  final double? cholesterolMg;

  factory FoodApiItem.fromJson(Map<String, dynamic> j) => FoodApiItem(
        foodCd: j['FOOD_CD']?.toString() ?? '',
        foodName: j['FOOD_NM_KR']?.toString() ?? '',
        servingSizeG: _d(j['SERVING_WT']),
        caloriesKcal: _d(j['AMT_NUM1']),
        proteinG: _d(j['AMT_NUM3']),
        fatG: _d(j['AMT_NUM4']),
        carbsG: _d(j['AMT_NUM6']),
        sodiumMg: _d(j['AMT_NUM12']),
        saturatedFatG: _dOrNull(j['AMT_NUM22']),
        cholesterolMg: _dOrNull(j['AMT_NUM21']),
        sugarG: _d(j['AMT_NUM24']),
      );

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s == '-') return 0.0;
    return double.tryParse(s) ?? 0.0;
  }

  static double? _dOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-') return null;
    return double.tryParse(s);
  }
}
