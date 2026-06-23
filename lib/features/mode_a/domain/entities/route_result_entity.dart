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

/// 대중교통 구간 단계 (ODsay subPath 원소)
class TransitStep {
  const TransitStep({
    required this.trafficType,
    required this.startName,
    required this.endName,
    required this.distanceM,
    required this.sectionTimeMin,
    this.lineInfo,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.stationCount = 0,
    this.stepPoints = const [],
  });

  /// 이동 수단: 1=지하철, 2=버스, 3=도보
  final int trafficType;
  final String startName;
  final String endName;
  final int distanceM;
  final int sectionTimeMin;
  final String? lineInfo;  // 버스번호 or 지하철 호선명
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final int stationCount;
  /// 이 구간의 상세 폴리라인 좌표 (도보=초록, 차량=파랑 별색 표시용)
  final List<LatLng> stepPoints;

  bool get isWalk    => trafficType == 3;
  bool get isBus     => trafficType == 2;
  bool get isSubway  => trafficType == 1;
  bool get isVehicle => isBus || isSubway;

  String get typeLabel => isWalk ? '도보' : isBus ? '버스' : '지하철';

  String get distanceLabel => distanceM < 1000
      ? '${distanceM}m'
      : '${(distanceM / 1000).toStringAsFixed(1)}km';

  /// 현재 단계의 행동 설명 ("남위례역까지 도보" / "3420번 탑승 → 복정역환승센터 하차")
  String get actionLabel {
    if (isWalk) return '$endName까지 도보';
    if (lineInfo != null && lineInfo!.isNotEmpty) {
      return '$lineInfo 탑승 · $endName 하차';
    }
    return '$endName 하차';
  }
}

/// 경로 안내 포인트 (Kakao Mobility sections.guides 원소)
class RouteGuide {
  const RouteGuide({
    required this.latitude,
    required this.longitude,
    required this.guidance,
    required this.type,
    required this.distanceM,
  });

  final double latitude;
  final double longitude;
  final String guidance;   // e.g. "500m 직진 후 우회전"
  final int type;          // 0=출발, 11=직진, 12=우회전, 13=좌회전, 14=U턴, 100=도착
  final int distanceM;     // to next guide

  bool get isArrival => type == 100;
  bool get isDeparture => type == 0;

  String get turnLabel => switch (type) {
    0   => '출발',
    11  => '직진',
    12  => '우회전',
    13  => '좌회전',
    14  => 'U턴',
    100 => '도착',
    _   => '직진',
  };
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
    this.guides = const [],
    this.transitSteps = const [],
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
  /// Kakao Mobility 응답에서 추출한 안내 포인트 (도보/자전거 내비게이션용)
  final List<RouteGuide> guides;
  /// ODsay 응답에서 추출한 대중교통 단계 목록 (대중교통 안내용)
  final List<TransitStep> transitSteps;

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
    List<RouteGuide>? guides,
    List<TransitStep>? transitSteps,
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
      guides: guides ?? this.guides,
      transitSteps: transitSteps ?? this.transitSteps,
    );
  }
}
