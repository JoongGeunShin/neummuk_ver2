class AppConstants {
  AppConstants._();

  static const double defaultWeightKg = 65.0;

  /// MET 값 (Metabolic Equivalent of Task) - https://pacompendium.com/
  static const Map<String, double> metValues = {
    'walk': 3.5,
    'walk_fast': 4.8,
    'bike': 6.0,
    'bike_moderate': 8.0,
    'transit': 1.5,
  };

  /// 소비 칼로리 = MET × 체중(kg) × 시간(hour)
  static double calculateKcal({
    required String transport,
    required double weightKg,
    required int durationSeconds,
  }) {
    final met = metValues[transport] ?? metValues['walk']!;
    final hours = durationSeconds / 3600.0;
    return met * weightKg * hours;
  }
  // 한국관광공사_국문 관광정보 서비스_GW
  static const String tourApiBaseUrl =
      'https://apis.data.go.kr/B551011/KorService2';
  static const String kakaoLocalBaseUrl =
      'https://dapi.kakao.com/v2/local';
  // 식품의약품안전처_식품영양성분DB정보
  static const String foodApiBaseUrl =
      'https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo02';

  // Kakao Mobility API (인증: Authorization: KakaoAK {REST_API_KEY})
  static const String kakaoMobilityBaseUrl =
      'https://apis-navi.kakaomobility.com/v1';
  // 다중 경유지 길찾기: POST $kakaoMobilityBaseUrl/waypoints/directions
  // 다중 목적지 길찾기: POST $kakaoMobilityBaseUrl/destinations/directions

  static const int restaurantContentTypeId = 39;
  static const int touristSightContentTypeId = 12;
  static const int tourActivityContentTypeId = 28;

  static const double defaultSearchRadiusKm = 2.0;
  static const double kcalMatchTolerancePct = 0.20;
}
