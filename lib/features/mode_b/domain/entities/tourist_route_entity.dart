class TouristRouteEntity {
  const TouristRouteEntity({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.durationMinutes,
    required this.kcal,
    required this.type,
    this.tags = const [],
    this.startLat,
    this.startLng,
    this.region,
    this.gpxpath,
    this.isLocal = false,
    this.distanceFromUserM,
    this.imageUrls = const [],
  });

  final String id;
  final String name;
  final double distanceKm;
  final int durationMinutes;
  final int kcal;
  final String type; // '도보' | '자전거'
  final List<String> tags;
  final double? startLat;
  final double? startLng;
  final String? region;
  final String? gpxpath; // GPX 경로 URL — 코스 선으로 그리기용
  final bool isLocal; // 현재 위치 지역 코스 여부
  final int? distanceFromUserM; // 현재 위치에서 코스까지 직선거리 (TourAPI dist 필드)
  final List<String> imageUrls; // 코스 대표 이미지 URLs

  bool get isWalking => type == '도보';
  bool get hasCoordinate => startLat != null && startLng != null;
  bool get hasDetailInfo => distanceKm > 0 && durationMinutes > 0;
  bool get hasImages => imageUrls.isNotEmpty;

  TouristRouteEntity copyWith({bool? isLocal, List<String>? imageUrls}) =>
      TouristRouteEntity(
        id: id,
        name: name,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        kcal: kcal,
        type: type,
        tags: tags,
        startLat: startLat,
        startLng: startLng,
        region: region,
        gpxpath: gpxpath,
        isLocal: isLocal ?? this.isLocal,
        distanceFromUserM: distanceFromUserM,
        imageUrls: imageUrls ?? this.imageUrls,
      );
}
