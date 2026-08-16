import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';

/// 식품의약품안전처 식품영양성분 DB API (FoodNtrCpntDbInfo02 / getFoodNtrCpntDbInq02) 호출.
///
/// AMT_NUM 필드 매핑 (FoodNtrCpntDbInfo02 기준):
///   AMT_NUM1  → 에너지(kcal)
///   AMT_NUM3  → 단백질(g)
///   AMT_NUM4  → 지방(g)
///   AMT_NUM6  → 탄수화물(g)
///   AMT_NUM7  → 당류(g)
///   AMT_NUM13 → 나트륨(mg)
///   AMT_NUM23 → 콜레스테롤(mg)
///   AMT_NUM24 → 포화지방산(g)
///
/// 서빙 사이즈 우선순위:
///   NUTRI_AMOUNT_SERVING(1회 섭취참고량)
///   → Z10500 (KDRI 기반 1회 제공량 — 예: 짜장면 600mL)
///   → DISH_ONE_SERVING(1회분량 참고량)
///   → _defaultServingG (음식 종류별 기본값)
///   영양소 수치는 SERVING_SIZE 기준이므로 1인분 기준으로 스케일링한다.
///
/// 필터링:
///   FOOD_OR_NM에 '외식'이 포함된 데이터만 사용.
///   주요 영양소(탄수화물+단백질+지방) 합계가 0인 불완전 데이터 제외.
class FoodApiDatasource {
  static const _timeout = Duration(seconds: 10);

  Future<List<FoodApiItem>> search(String foodName, {int numOfRows = 10}) async {
    if (AppEnv.dataGoKey.isEmpty) {
      debugPrint('[FoodApi] DATA_GO_KEY not set');
      return [];
    }

    final uri = Uri.parse(
      '${AppConstants.foodApiBaseUrl}/${AppConstants.foodApiEndpoint}',
    ).replace(queryParameters: {
      'serviceKey': AppEnv.dataGoKey,
      'pageNo': '1',
      'numOfRows': numOfRows.toString(),
      'FOOD_NM_KR': foodName,
      'type': 'json',
    });

    try {
      final keyPreview = AppEnv.dataGoKey.length > 8
          ? '${AppEnv.dataGoKey.substring(0, 8)}...'
          : '(empty)';
      debugPrint('[FoodApi] search: $foodName | key: $keyPreview');
      final res = await http.get(uri).timeout(_timeout);
      debugPrint('[FoodApi] HTTP ${res.statusCode}');
      if (res.statusCode != 200) {
        debugPrint('[FoodApi] error body: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
        return [];
      }
      final items = _parse(res.body);
      debugPrint('[FoodApi] parsed ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('[FoodApi] search error: $e');
      return [];
    }
  }

  List<FoodApiItem> _parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
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
          .where((item) =>
              item.foodName.isNotEmpty &&
              item.caloriesKcal > 0 &&
              // 주요 영양소 모두 0이면 불완전 데이터 → 제외
              (item.carbsG + item.proteinG + item.fatG) > 0 &&
              // 외식 데이터만 사용 (가공식품·농산물 등 제외)
              item.foodOrNm.contains('외식'))
          .toList();
    } catch (e) {
      debugPrint('[FoodApi] parse error: $e');
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
    required this.saturatedFatG,
    required this.cholesterolMg,
    this.dbClassName = '',
    this.foodCat1Name = '',
    this.foodCat2Name = '',
    this.foodOrNm = '',
  });

  final String foodCd;
  final String foodName;
  /// 1인분 기준량 (NUTRI_AMOUNT_SERVING → Z10500 → DISH_ONE_SERVING → 기본값)
  final double servingSizeG;
  final double caloriesKcal;
  final double carbsG;
  final double sugarG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double saturatedFatG;
  final double cholesterolMg;
  final String dbClassName;
  final String foodCat1Name;
  final String foodCat2Name;
  /// 식품 기원명 (외식/가공식품/농산물 등)
  final String foodOrNm;

  factory FoodApiItem.fromJson(Map<String, dynamic> j) {
    // 영양소 기준 참조량 (SERVING_SIZE)
    final refG = _d(j['SERVING_SIZE']);
    final servingRef = refG > 0 ? refG : 100.0;

    // 1인분 기준: NUTRI_AMOUNT_SERVING → Z10500 → DISH_ONE_SERVING → 기본값
    final nutri1 = _parseServingG(j['NUTRI_AMOUNT_SERVING']?.toString());
    final z10500 = _parseServingG(j['Z10500']?.toString()); // KDRI 1회 제공량
    final dish1 = _parseServingG(j['DISH_ONE_SERVING']?.toString());
    final foodName = j['FOOD_NM_KR']?.toString() ?? '';
    final cat1 = j['FOOD_CAT1_NM']?.toString() ?? '';
    final cat2 = j['FOOD_CAT2_NM']?.toString() ?? '';

    final serving1Portion = nutri1 > 0
        ? nutri1
        : (z10500 > 0 && z10500 != servingRef
            ? z10500
            : (dish1 > 0 ? dish1 : _defaultServingG(foodName, cat1, cat2)));

    final scale = serving1Portion / servingRef;

    return FoodApiItem(
      foodCd: j['FOOD_CD']?.toString() ?? '',
      foodName: foodName,
      servingSizeG: serving1Portion,
      caloriesKcal: _d(j['AMT_NUM1']) * scale,
      proteinG: _d(j['AMT_NUM3']) * scale,
      fatG: _d(j['AMT_NUM4']) * scale,
      carbsG: _d(j['AMT_NUM6']) * scale,
      sugarG: _d(j['AMT_NUM7']) * scale,
      sodiumMg: _d(j['AMT_NUM13']) * scale,
      cholesterolMg: _d(j['AMT_NUM23']) * scale,
      saturatedFatG: _d(j['AMT_NUM24']) * scale,
      dbClassName: j['DB_CLASS_NM']?.toString() ?? '',
      foodCat1Name: cat1,
      foodCat2Name: cat2,
      foodOrNm: j['FOOD_OR_NM']?.toString() ?? '',
    );
  }

  /// API에 1회 섭취참고량이 없을 때 음식 종류별 기본 1인분 기준 (g).
  /// Z10500이 있으면 이 값은 사용되지 않는다.
  static double _defaultServingG(String name, String cat1, String cat2) {
    bool has(List<String> kw) => kw.any(name.contains);
    if (has(['찌개', '전골'])) return 400.0;
    if (has(['국', '탕', '설렁탕', '곰탕', '갈비탕', '순대국'])) return 500.0;
    if (has(['짜장', '짜장면', '라면', '짬뽕', '쌀국수', '냉면', '칼국수', '국수', '콩국수'])) return 600.0;
    if (has(['우동', '소바'])) return 500.0;
    if (has(['볶음밥', '비빔밥', '덮밥'])) return 350.0;
    if (has(['밥'])) return 300.0;
    if (has(['치킨', '프라이드', '닭강정', '양념치킨'])) return 300.0;
    if (has(['피자'])) return 250.0;
    if (has(['파스타', '스파게티', '리소토'])) return 300.0;
    if (has(['햄버거', '버거'])) return 200.0;
    if (has(['떡볶이'])) return 350.0;
    if (has(['삼겹살', '목살', '항정살'])) return 200.0;
    if (has(['갈비', '불고기', '제육'])) return 200.0;
    if (has(['초밥', '스시'])) return 200.0;
    if (has(['커피', '아메리카노', '라테', '카페'])) return 240.0;
    if (has(['주스', '음료'])) return 240.0;
    if (has(['케이크'])) return 100.0;
    if (has(['빵', '식빵'])) return 80.0;
    if (has(['과자', '쿠키', '스낵', '칩'])) return 50.0;
    if (cat1.contains('음료') || cat2.contains('음료')) return 240.0;
    return 200.0;
  }

  /// "600g", "1인분(600g)", "600ml", "600" 등에서 g/ml 수치를 파싱.
  static double _parseServingG(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == '-') return 0.0;
    final unitMatch = RegExp(
      r'([\d.]+)\s*(?:g|ml|mL|㎖|㎏|cc)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (unitMatch != null) return double.tryParse(unitMatch.group(1)!) ?? 0.0;
    final nums = RegExp(r'[\d.]+')
        .allMatches(raw)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .where((v) => v > 5)
        .toList();
    if (nums.isEmpty) return 0.0;
    return nums.reduce((a, b) => a > b ? a : b);
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s == '-') return 0.0;
    return double.tryParse(s) ?? 0.0;
  }
}
