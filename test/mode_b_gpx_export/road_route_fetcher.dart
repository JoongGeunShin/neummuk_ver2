import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:neummuk_ver2/features/mode_b/domain/entities/tourist_route_entity.dart';

/// mode_b_mixin.dart의 _fetchApproachRoute/_fetchAllSegmentPolylines와 동일한 순서
/// (TMAP 보행자 경로 우선 → Kakao Mobility 차량 경로 폴백)로 구간별 도로 좌표를 가져온다.
/// 앱이 실제로 화면에 그리고 내비게이션 잔여거리 계산에 쓰는 경로와 동일한 모양을 재현하기 위함.
class RoadPoint {
  const RoadPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// [waypoints]는 TouristRouteEntity.waypoints — 생성 코스라면 스팟들 + 마지막 '출발지' 복귀 지점.
/// 반환값은 출발지 좌표를 포함한 전체 구간의 순서 있는 도로 좌표 목록.
Future<List<RoadPoint>> fetchGeneratedCourseRoadRoute({
  required double startLat,
  required double startLng,
  required List<SpotWaypoint> waypoints,
}) async {
  final all = <RoadPoint>[RoadPoint(startLat, startLng)];
  var prevLat = startLat;
  var prevLng = startLng;

  for (final wp in waypoints) {
    final legPoints = await _fetchLeg(
      fromLat: prevLat,
      fromLng: prevLng,
      toLat: wp.lat,
      toLng: wp.lng,
    );
    if (legPoints.isNotEmpty) {
      all.addAll(legPoints);
    } else {
      // 두 API 모두 실패하면 직선으로 폴백 (앱 쪽 로직과 동일) — 위 로그로 원인 확인할 것
      // ignore: avoid_print
      print('[RoadRoute] $prevLat,$prevLng → ${wp.lat},${wp.lng}: '
          '도로 경로 조회 실패, 직선으로 대체됨');
      all.add(RoadPoint(wp.lat, wp.lng));
    }
    prevLat = wp.lat;
    prevLng = wp.lng;
  }
  return all;
}

Future<List<RoadPoint>> _fetchLeg({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  final tmapKey = dotenv.env['TMAP_APP_KEY'] ?? '';
  if (tmapKey.isNotEmpty) {
    final pts = await _fetchTmapPedestrianLeg(
      fromLat: fromLat, fromLng: fromLng,
      toLat: toLat, toLng: toLng,
      tmapKey: tmapKey,
    );
    if (pts.isNotEmpty) return pts;
  }

  final kakaoKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
  if (kakaoKey.isNotEmpty) {
    return _fetchKakaoCarLeg(
      fromLat: fromLat, fromLng: fromLng,
      toLat: toLat, toLng: toLng,
      kakaoKey: kakaoKey,
    );
  }

  return const [];
}

Future<List<RoadPoint>> _fetchTmapPedestrianLeg({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  required String tmapKey,
}) async {
  try {
    final body = [
      'startX=$fromLng',
      'startY=$fromLat',
      'endX=$toLng',
      'endY=$toLat',
      'startName=${Uri.encodeComponent('출발')}',
      'endName=${Uri.encodeComponent('도착')}',
      'reqCoordType=WGS84GEO',
      'resCoordType=WGS84GEO',
      'searchOption=0',
    ].join('&');

    final res = await http
        .post(
          Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1'),
          headers: {
            'appKey': tmapKey,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[TMAP] leg $fromLat,$fromLng → $toLat,$toLng 실패: '
          'status=${res.statusCode} body=${_head(res.body)}');
      return const [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List?;
    if (features == null) return const [];

    final points = <RoadPoint>[];
    for (final feature in features) {
      final geometry = (feature as Map)['geometry'] as Map?;
      if (geometry == null || geometry['type'] != 'LineString') continue;
      final coords = geometry['coordinates'] as List?;
      if (coords == null) continue;
      for (final c in coords) {
        points.add(RoadPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    return points;
  } catch (e) {
    // ignore: avoid_print
    print('[TMAP] leg $fromLat,$fromLng → $toLat,$toLng 예외: $e');
    return const [];
  }
}

String _head(String s) => s.length > 300 ? s.substring(0, 300) : s;

Future<List<RoadPoint>> _fetchKakaoCarLeg({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  required String kakaoKey,
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('https://apis-navi.kakaomobility.com/v1/waypoints/directions'),
          headers: {
            'Authorization': 'KakaoAK $kakaoKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'origin': {'x': fromLng, 'y': fromLat},
            'destination': {'x': toLng, 'y': toLat},
            'waypoints': [],
            'priority': 'RECOMMEND',
            'road_details': false,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[KakaoMobility] leg $fromLat,$fromLng → $toLat,$toLng 실패: '
          'status=${res.statusCode} body=${_head(res.body)}');
      return const [];
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return const [];
    final route = routes[0] as Map<String, dynamic>;
    if ((route['result_code'] as num? ?? -1).toInt() != 0) {
      // ignore: avoid_print
      print('[KakaoMobility] leg $fromLat,$fromLng → $toLat,$toLng '
          'result_code=${route['result_code']} msg=${route['result_msg']}');
      return const [];
    }

    final points = <RoadPoint>[];
    for (final section in (route['sections'] as List? ?? [])) {
      for (final road in ((section as Map)['roads'] as List? ?? [])) {
        final vx = (road as Map)['vertexes'] as List? ?? [];
        for (var i = 0; i < vx.length - 1; i += 2) {
          points.add(RoadPoint(
            (vx[i + 1] as num).toDouble(),
            (vx[i] as num).toDouble(),
          ));
        }
      }
    }
    return points;
  } catch (e) {
    // ignore: avoid_print
    print('[KakaoMobility] leg $fromLat,$fromLng → $toLat,$toLng 예외: $e');
    return const [];
  }
}
