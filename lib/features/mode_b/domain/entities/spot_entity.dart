enum SpotTag {
  touristSight, // 관광지/관광명소
  culture, // 문화시설
  event, // 행사/공연/축제
  sports, // 레포츠
  shopping, // 쇼핑
}

extension SpotTagExt on SpotTag {
  String get label => switch (this) {
        SpotTag.touristSight => '관광지/관광명소',
        SpotTag.culture => '문화시설',
        SpotTag.event => '행사/공연/축제',
        SpotTag.sports => '레포츠',
        SpotTag.shopping => '쇼핑',
      };

  String get emoji => switch (this) {
        SpotTag.touristSight => '🏛️',
        SpotTag.culture => '🎭',
        SpotTag.event => '🎉',
        SpotTag.sports => '⛹️',
        SpotTag.shopping => '🛍️',
      };

  // TourAPI contentTypeId (null = not supported)
  int? get tourApiContentTypeId => switch (this) {
        SpotTag.touristSight => 12,
        SpotTag.culture => 14,
        SpotTag.event => 15,
        SpotTag.sports => 28,
        SpotTag.shopping => 38,
      };

  // Kakao Local categoryGroupCodes
  List<String> get kakaoGroupCodes => switch (this) {
        SpotTag.touristSight => ['AT4'],
        SpotTag.culture => ['CT1'],
        SpotTag.event => [],
        SpotTag.sports => [],
        SpotTag.shopping => [],
      };
}

class SpotEntity {
  const SpotEntity({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.source,
    this.category,
    this.address,
    this.imageUrl,
    this.distanceFromUserM,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type; // 'tourist_sight' | 'culture' | 'event' | 'sports' | 'shopping'
  final String source; // 'kakao' | 'tour_api'
  final String? category;
  final String? address;
  final String? imageUrl;
  final int? distanceFromUserM;
}
