class RestaurantEntity {
  const RestaurantEntity({
    required this.id,
    required this.name,
    required this.menu,
    required this.category,
    required this.kcal,
    required this.distanceM,
    required this.walkMinutes,
    required this.rating,
    required this.reviewCount,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.tags = const [],
    this.imageType = 'generic',
    this.address,
    this.tel,
    this.contentId,
    this.kakaoPlaceId,
  });

  final String id;
  final String name;
  final String menu;
  final String category;
  final int kcal;
  final int distanceM;
  final int walkMinutes;
  final double rating;
  final int reviewCount;
  final double latitude;
  final double longitude;
  final String kind; // 'food' | 'cafe'
  final List<String> tags;
  final String imageType;
  final String? address;
  final String? tel;
  final String? contentId;
  final String? kakaoPlaceId;

  String get distanceLabel =>
      distanceM < 1000 ? '${distanceM}m' : '${(distanceM / 1000).toStringAsFixed(1)}km';
  String get walkLabel => '도보 $walkMinutes분';
}
