/// 경유지 한 개 (Kakao Mobility waypoints/destinations API 좌표 형식)
class RouteWaypoint {
  const RouteWaypoint({
    required this.name,
    required this.longitude, // Kakao API: x
    required this.latitude,  // Kakao API: y
  });

  final String name;
  final double longitude;
  final double latitude;
}

/// 경로 상의 GPS 좌표 한 점 (Kakao Mobility 응답 vertexes 배열 원소)
class LatLng {
  const LatLng({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

class RouteResultEntity {
  const RouteResultEntity({
    required this.fromName,
    required this.toName,
    required this.distanceKm,
    required this.durationSeconds,
    required this.transport,
    required this.kcalBurn,
    this.waypoints = const [],
    this.routePoints = const [],
  });

  final String fromName;
  final String toName;
  final double distanceKm;
  final int durationSeconds;
  final String transport; // 'walk' | 'bike' | 'transit' | 'car'
  final int kcalBurn;
  /// 중간 경유 관광지 목록 (Kakao Mobility waypoints 파라미터로 전달)
  final List<RouteWaypoint> waypoints;
  /// Kakao Mobility 응답에서 추출한 폴리라인 좌표 (지도 표시용)
  final List<LatLng> routePoints;

  int get durationMinutes => (durationSeconds / 60).round();

  RouteResultEntity copyWith({
    String? fromName,
    String? toName,
    double? distanceKm,
    int? durationSeconds,
    String? transport,
    int? kcalBurn,
    List<RouteWaypoint>? waypoints,
    List<LatLng>? routePoints,
  }) {
    return RouteResultEntity(
      fromName: fromName ?? this.fromName,
      toName: toName ?? this.toName,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transport: transport ?? this.transport,
      kcalBurn: kcalBurn ?? this.kcalBurn,
      waypoints: waypoints ?? this.waypoints,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}
