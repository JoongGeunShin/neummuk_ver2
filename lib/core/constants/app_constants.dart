import '../models/body_metrics.dart';

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

  /// Mifflin-St Jeor 기본대사량(kcal/day). 성별·키·나이를 반영해 칼로리를 개인화한다.
  static double calculateBmr(BodyMetrics m) {
    final base = 10 * m.weightKg + 6.25 * m.heightCm - 5 * m.age;
    return m.sex == 'female' ? base - 161 : base + 5;
  }

  /// MET 값을 직접 받아 시간당 소모 칼로리(kcal/h)를 계산하는 단일 원천 공식.
  /// [kcalPerHour](고정 transport→MET 조회)와 foreground 걸음 추적의 실측 속도
  /// 기반 MET(WalkCalculator.met())이 모두 이 함수로 수렴해, "어디서 재느냐"에
  /// 따라 칼로리 공식 자체가 달라지지 않도록 한다.
  static double kcalPerHourFromMet({
    required double met,
    required BodyMetrics metrics,
  }) {
    return met * (calculateBmr(metrics) / 24.0);
  }

  /// 이동수단별 시간당 소모 칼로리(kcal/h) = MET × (BMR/24)
  static double kcalPerHour({
    required String transport,
    required BodyMetrics metrics,
  }) {
    final met = metValues[transport] ?? metValues['walk']!;
    return kcalPerHourFromMet(met: met, metrics: metrics);
  }

  /// MET 값을 직접 받아 소비 칼로리 = MET × (BMR/24) × 시간(hour)을 계산한다.
  static double calculateKcalFromMet({
    required double met,
    required BodyMetrics metrics,
    required int durationSeconds,
  }) {
    return kcalPerHourFromMet(met: met, metrics: metrics) *
        durationSeconds /
        3600.0;
  }

  /// 소비 칼로리 = MET × (BMR/24) × 시간(hour)
  static double calculateKcal({
    required String transport,
    required BodyMetrics metrics,
    required int durationSeconds,
  }) {
    final met = metValues[transport] ?? metValues['walk']!;
    return calculateKcalFromMet(
        met: met, metrics: metrics, durationSeconds: durationSeconds);
  }

  /// targetKcal 소모에 필요한 이동 시간(hour) 역산
  static double hoursForTargetKcal({
    required String transport,
    required BodyMetrics metrics,
    required int targetKcal,
  }) {
    return targetKcal / kcalPerHour(transport: transport, metrics: metrics);
  }
  // 한국관광공사_국문 관광정보 서비스_GW
  static const String tourApiBaseUrl =
      'https://apis.data.go.kr/B551011/KorService2';
  static const String kakaoLocalBaseUrl =
      'https://dapi.kakao.com/v2/local';
  // 식품의약품안전처_식품영양성분 DB (FoodNtrCpntDbInfo02 / getFoodNtrCpntDbInq02)
  static const String foodApiBaseUrl =
      'https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo02';
  static const String foodApiEndpoint = 'getFoodNtrCpntDbInq02';

  // Kakao Mobility API (인증: Authorization: KakaoAK {REST_API_KEY})
  // 한국관광공사_두루누비 정보 서비스 (산책로·자전거길 코스)
  static const String durunubiBaseUrl =
      'https://apis.data.go.kr/B551011/Durunubi';

  static const String kakaoMobilityBaseUrl =
      'https://apis-navi.kakaomobility.com/v1';
  // 다중 경유지 길찾기: POST $kakaoMobilityBaseUrl/waypoints/directions
  // 다중 목적지 길찾기: POST $kakaoMobilityBaseUrl/destinations/directions

  static const int restaurantContentTypeId = 39;
  static const int touristSightContentTypeId = 12;
  static const int tourActivityContentTypeId = 28;

  static const double defaultSearchRadiusKm = 2.0;
  static const double kcalMatchTolerancePct = 0.20;

  /// Mode B 검색 반경(m) — 이동수단별 공통값 (기성 코스·스팟 검색 모두 사용)
  static const int modeBWalkRadiusM = 3000;
  static const int modeBBikeRadiusM = 5000;

  /// 내비게이션 이탈 판정 통합 임계값(m) — Mode A/B 공용.
  /// provider(off-route 플래그), 폴리라인 트리밍 색상, 자동 재경로 트리거가
  /// 모두 이 값을 공유해 화면과 판정 로직이 서로 다른 기준으로 어긋나지 않도록 한다.
  static const double offRouteThresholdM = 80.0;
}
