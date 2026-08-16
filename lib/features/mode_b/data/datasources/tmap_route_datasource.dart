import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/spot_entity.dart';

/// 스팟 경유 왕복 코스의 실제 도로 거리 조회 (TMAP 보행자 API 우선, 실패 시 Kakao Mobility 폴백)
///
/// [ModeBCourseGenerator]의 스팟 선택은 직선거리×보정계수 추정치를 쓰기 때문에
/// 실제 도로망과 오차가 클 수 있다. 이 클래스는 선택이 끝난 스팟 조합에 대해
/// 실측 거리를 조회해, 리포지토리가 목표 칼로리에 맞게 스팟 구성을 보정할 수 있게 한다.
class TmapRouteDatasource {
  String get _tmapKey => AppEnv.tmapAppKey;
  String get _kakaoKey => AppEnv.kakaoRestApiKey;

  /// [startLat]/[startLng] 출발 → [orderedSpots] 순서대로 경유 → 출발지 복귀.
  /// 왕복 총 도로 거리(km). 두 API 모두 실패하면 null (호출부는 직선거리 추정치로 폴백).
  Future<double?> fetchRoundTripDistanceKm({
    required double startLat,
    required double startLng,
    required List<SpotEntity> orderedSpots,
  }) async {
    if (orderedSpots.isEmpty) return null;

    final tmapKm = await _fetchTmapDistanceKm(
      startLat: startLat,
      startLng: startLng,
      orderedSpots: orderedSpots,
    );
    if (tmapKm != null) return tmapKm;

    return _fetchKakaoDistanceKm(
      startLat: startLat,
      startLng: startLng,
      orderedSpots: orderedSpots,
    );
  }

  // ── TMAP 보행자 API (passList 경유지 지원) ──────────────────────────

  Future<double?> _fetchTmapDistanceKm({
    required double startLat,
    required double startLng,
    required List<SpotEntity> orderedSpots,
  }) async {
    try {
      final key = _tmapKey;
      if (key.isEmpty) return null;

      // 목적지 = 출발지로 복귀(왕복), 경유지 = 선택된 스팟 전체 (최대 5개까지 지원)
      const maxPass = 5;
      final intermediates = orderedSpots.length <= maxPass
          ? orderedSpots
          : List.generate(
              maxPass,
              (i) => orderedSpots[
                  (i * (orderedSpots.length - 1) ~/ (maxPass - 1))
                      .clamp(0, orderedSpots.length - 1)],
            );

      final bodyParts = [
        'startX=$startLng',
        'startY=$startLat',
        'endX=$startLng',
        'endY=$startLat',
        'startName=${Uri.encodeComponent('출발')}',
        'endName=${Uri.encodeComponent('복귀')}',
        'reqCoordType=WGS84GEO',
        'resCoordType=WGS84GEO',
        'searchOption=0',
        'passList=${intermediates.map((s) => '${s.lng},${s.lat}').join('_')}',
      ];

      final res = await http
          .post(
            Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1'),
            headers: {
              'appKey': key,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: bodyParts.join('&'),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('[TmapRoute] status=${res.statusCode}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List?;
      if (features == null || features.isEmpty) return null;

      double distM = 0;
      ({double lat, double lng})? prev;
      for (final feature in features) {
        final geometry = (feature as Map)['geometry'] as Map?;
        if (geometry == null || geometry['type'] != 'LineString') continue;
        final coords = geometry['coordinates'] as List?;
        if (coords == null) continue;
        for (final c in coords) {
          final pt = (lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble());
          if (prev != null) distM += haversineDistanceM(prev.lat, prev.lng, pt.lat, pt.lng);
          prev = pt;
        }
      }
      return distM > 0 ? distM / 1000.0 : null;
    } catch (e) {
      debugPrint('[TmapRoute] error=$e');
      return null;
    }
  }

  // ── Kakao Mobility 폴백 (summary.distance 직접 사용) ─────────────────

  Future<double?> _fetchKakaoDistanceKm({
    required double startLat,
    required double startLng,
    required List<SpotEntity> orderedSpots,
  }) async {
    try {
      final key = _kakaoKey;
      if (key.isEmpty) return null;

      final res = await http
          .post(
            Uri.parse('${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions'),
            headers: {
              'Authorization': 'KakaoAK $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'origin': {'x': startLng, 'y': startLat},
              'destination': {'x': startLng, 'y': startLat},
              'waypoints': orderedSpots
                  .map((s) => {'name': s.name, 'x': s.lng, 'y': s.lat})
                  .toList(),
              'priority': 'RECOMMEND',
              'road_details': false,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes[0] as Map<String, dynamic>;
      if ((route['result_code'] as num? ?? -1).toInt() != 0) return null;

      final summary = route['summary'] as Map<String, dynamic>?;
      final distanceM = (summary?['distance'] as num?)?.toDouble();
      return distanceM != null && distanceM > 0 ? distanceM / 1000.0 : null;
    } catch (e) {
      debugPrint('[TmapRoute] Kakao fallback error=$e');
      return null;
    }
  }

}
