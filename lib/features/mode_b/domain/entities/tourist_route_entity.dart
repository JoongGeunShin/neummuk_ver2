import 'dart:convert';

class SpotWaypoint {
  const SpotWaypoint({
    required this.name,
    required this.lat,
    required this.lng,
    this.type,
  });

  final String name;
  final double lat;
  final double lng;
  final String? type;

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng, 'type': type};

  factory SpotWaypoint.fromJson(Map<String, dynamic> j) => SpotWaypoint(
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        type: j['type'] as String?,
      );
}

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
    this.endLat,
    this.endLng,
    this.region,
    this.gpxpath,
    this.isLocal = false,
    this.distanceFromUserM,
    this.imageUrls = const [],
    this.waypoints = const [],
    this.isGenerated = false,
    this.source = 'durunubi',
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
  final double? endLat;
  final double? endLng;
  final String? region;
  final String? gpxpath;
  final bool isLocal;
  final int? distanceFromUserM;
  final List<String> imageUrls;

  /// 스팟 기반 생성 코스의 경유지 목록
  final List<SpotWaypoint> waypoints;

  /// true = 스팟 조합으로 생성된 코스
  final bool isGenerated;

  /// 'durunubi' | 'tour_api' | 'generated'
  final String source;

  bool get isWalking => type == '도보';
  bool get hasCoordinate => startLat != null && startLng != null;
  bool get hasDetailInfo => distanceKm > 0 && durationMinutes > 0;
  bool get hasImages => imageUrls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'kcal': kcal,
        'type': type,
        'tags': tags,
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        'region': region,
        'gpxpath': gpxpath,
        'isLocal': isLocal,
        'distanceFromUserM': distanceFromUserM,
        'imageUrls': imageUrls,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'isGenerated': isGenerated,
        'source': source,
      };

  factory TouristRouteEntity.fromJson(Map<String, dynamic> j) => TouristRouteEntity(
        id: j['id'] as String,
        name: j['name'] as String,
        distanceKm: (j['distanceKm'] as num).toDouble(),
        durationMinutes: j['durationMinutes'] as int,
        kcal: j['kcal'] as int,
        type: j['type'] as String,
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        startLat: (j['startLat'] as num?)?.toDouble(),
        startLng: (j['startLng'] as num?)?.toDouble(),
        endLat: (j['endLat'] as num?)?.toDouble(),
        endLng: (j['endLng'] as num?)?.toDouble(),
        region: j['region'] as String?,
        gpxpath: j['gpxpath'] as String?,
        isLocal: j['isLocal'] as bool? ?? false,
        distanceFromUserM: j['distanceFromUserM'] as int?,
        imageUrls: (j['imageUrls'] as List?)?.cast<String>() ?? const [],
        waypoints: (j['waypoints'] as List?)
                ?.map((w) => SpotWaypoint.fromJson(w as Map<String, dynamic>))
                .toList() ??
            const [],
        isGenerated: j['isGenerated'] as bool? ?? false,
        source: j['source'] as String? ?? 'durunubi',
      );

  static TouristRouteEntity fromJsonStr(String s) =>
      TouristRouteEntity.fromJson(jsonDecode(s) as Map<String, dynamic>);

  TouristRouteEntity copyWith({
    bool? isLocal,
    List<String>? imageUrls,
    double? distanceKm,
    int? durationMinutes,
    int? kcal,
    List<String>? tags,
    List<SpotWaypoint>? waypoints,
    bool? isGenerated,
    String? source,
    double? endLat,
    double? endLng,
  }) =>
      TouristRouteEntity(
        id: id,
        name: name,
        distanceKm: distanceKm ?? this.distanceKm,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        kcal: kcal ?? this.kcal,
        type: type,
        tags: tags ?? this.tags,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat ?? this.endLat,
        endLng: endLng ?? this.endLng,
        region: region,
        gpxpath: gpxpath,
        isLocal: isLocal ?? this.isLocal,
        distanceFromUserM: distanceFromUserM,
        imageUrls: imageUrls ?? this.imageUrls,
        waypoints: waypoints ?? this.waypoints,
        isGenerated: isGenerated ?? this.isGenerated,
        source: source ?? this.source,
      );
}
