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
}
