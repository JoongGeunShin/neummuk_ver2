enum PlaceSource { tourApi, kakaoLocal, both }

class PlaceEntity {
  const PlaceEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.imageUrl,
    this.category,
    required this.source,
    this.contentTypeId,
    this.menu,
    this.kcalEstimate,
    this.targetKcal,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? imageUrl;
  final String? category;
  final PlaceSource source;

  /// TourAPI contentTypeId (12=관광지, 14=문화시설, 15=축제행사, 25=여행코스)
  final int? contentTypeId;

  // ── 음식점 매칭 결과(mode_a 도착 후 맛집, mode_match "오늘의 맞춤 맛집")에서만 채워짐 ──
  /// 매칭 근거가 된 메뉴명 (food_catalog 실측값)
  final String? menu;

  /// 위 메뉴의 예상 칼로리
  final int? kcalEstimate;

  /// 비교 기준 칼로리(오늘 소모/burn 등) — kcalEstimate와 짝을 이룰 때만 의미 있음
  final int? targetKcal;

  /// kcalEstimate - targetKcal. 둘 다 있을 때만 계산됨.
  int? get kcalDiff => (kcalEstimate != null && targetKcal != null)
      ? kcalEstimate! - targetKcal!
      : null;
}
