import 'dart:math' as math;

/// 두 좌표 사이의 정밀 대권거리(Haversine) — 미터 단위.
/// 코스 생성·거리 보정 등 배치성 계산에 사용할 것. 매 GPS 틱마다 호출되는
/// 실시간 근접점 탐색처럼 호출 빈도가 매우 높은 곳에는 [fastDistanceM]을 쓴다.
double haversineDistanceM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  const toRad = math.pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * toRad) *
          math.cos(lat2 * toRad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// [haversineDistanceM]의 킬로미터 단위 버전.
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) =>
    haversineDistanceM(lat1, lng1, lat2, lng2) / 1000.0;

/// Equirectangular 근사 거리(미터) — 오차 ~0.1% 이내, [haversineDistanceM]보다 빠르다.
/// GPS 위치 업데이트마다 반복 호출되는 실시간 최근접점 탐색 등 정밀도보다
/// 속도가 중요한 곳에 사용한다.
double fastDistanceM(double lat1, double lng1, double lat2, double lng2) {
  const toRad = math.pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;
  final cosLat = math.cos(lat1 * toRad);
  return 6371000.0 * math.sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
}
