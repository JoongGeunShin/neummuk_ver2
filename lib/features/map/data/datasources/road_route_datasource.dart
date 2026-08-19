import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../../../core/utils/geo_utils.dart';

/// 위경도 좌표 한 점 — 지도 SDK(NLatLng)나 도메인 엔티티(LatLng)에 종속되지 않는
/// 순수 데이터 레이어 표현. 호출측에서 각자의 타입으로 변환해 사용한다.
typedef GeoPoint = ({double lat, double lng});

/// Kakao Mobility 응답에서 추출한 방향 안내 포인트.
class RouteGuidePoint {
  const RouteGuidePoint({
    required this.lat,
    required this.lng,
    required this.guidance,
    required this.type,
    required this.distanceM,
  });

  final double lat;
  final double lng;
  final String guidance;
  final int type; // 0=출발, 11=직진, 12=우회전, 13=좌회전, 14=U턴, 100=도착
  final int distanceM;
}

/// TMAP 보행자 API를 우선 사용하고, 구간 전체가 실패하면 Kakao Mobility로
/// 코스 전체를 재시도하는 실도로 경로 조회 — Mode A/B 공용.
///
/// 구간별로 독립적으로 TMAP→Kakao 폴백을 판단하면 한 코스 안에서 도로 스냅
/// 스타일이 섞여 부자연스러운 경로가 나올 수 있어, "전체 성공/전체 실패" 단위로만
/// 소스를 전환한다.
class RoadRouteDatasource {
  const RoadRouteDatasource();

  /// 여러 구간(출발지→경유지1→...→목적지)의 도로 경로를 한 번에 가져온다.
  /// TMAP으로 전 구간을 먼저 시도하고, 단 한 구간이라도 실패하면 전체를 버리고
  /// Kakao Mobility로 코스 전체를 다시 시도한다.
  Future<
    ({
      List<List<GeoPoint>> segments,
      List<RouteGuidePoint> guides,
      String? source,
    })
  >
  fetchRouteWithFallback({
    required double startLat,
    required double startLng,
    required List<GeoPoint> waypoints,
  }) async {
    final tmapPass = await _fetchLegsBySource(
      startLat: startLat,
      startLng: startLng,
      waypoints: waypoints,
      source: 'tmap',
    );
    if (tmapPass.allSucceeded) {
      return (
        segments: tmapPass.segments,
        guides: const <RouteGuidePoint>[],
        source: 'tmap',
      );
    }

    debugPrint('[RoadRoute] TMAP으로 전체 구간을 채우지 못해 Kakao로 전체 재시도');
    final kakaoPass = await _fetchLegsBySource(
      startLat: startLat,
      startLng: startLng,
      waypoints: waypoints,
      source: 'kakao',
    );
    return (
      segments: kakaoPass.segments,
      guides: kakaoPass.guides,
      source: kakaoPass.allSucceeded ? 'kakao' : null,
    );
  }

  /// [source]("tmap" | "kakao") 하나만으로 전 구간을 시도한다. 실패한 구간은
  /// 직선으로 채우되 [allSucceeded]로 실제 전체 성공 여부를 함께 반환한다.
  Future<
    ({
      List<List<GeoPoint>> segments,
      List<RouteGuidePoint> guides,
      bool allSucceeded,
    })
  >
  _fetchLegsBySource({
    required double startLat,
    required double startLng,
    required List<GeoPoint> waypoints,
    required String source,
  }) async {
    final segments = <List<GeoPoint>>[];
    final guides = <RouteGuidePoint>[];
    var allSucceeded = true;
    double prevLat = startLat, prevLng = startLng;

    for (final wp in waypoints) {
      List<GeoPoint> pts;
      if (source == 'tmap') {
        pts = await fetchTmapLeg(
          fromLat: prevLat,
          fromLng: prevLng,
          toLat: wp.lat,
          toLng: wp.lng,
        );
      } else {
        final kakao = await fetchKakaoMobilityLeg(
          fromLat: prevLat,
          fromLng: prevLng,
          toLat: wp.lat,
          toLng: wp.lng,
        );
        pts = kakao.points;
        guides.addAll(kakao.guides);
      }

      if (pts.isNotEmpty) {
        segments.add(withSnapPrefix(prevLat, prevLng, pts));
      } else {
        segments.add([
          (lat: prevLat, lng: prevLng),
          (lat: wp.lat, lng: wp.lng),
        ]);
        allSucceeded = false;
      }
      prevLat = wp.lat;
      prevLng = wp.lng;
    }
    return (segments: segments, guides: guides, allSucceeded: allSucceeded);
  }

  /// 재경로(reroute)용 단일 구간 조회 — [preferredSource]가 'kakao'가 아니면 TMAP을
  /// 먼저 시도하고, 실패 시(혹은 preferredSource가 'kakao'면 곧바로) Kakao로 대체한다.
  Future<List<GeoPoint>> fetchSingleLeg({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? preferredSource,
  }) async {
    if (preferredSource != 'kakao') {
      final pts = await fetchTmapLeg(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (pts.isNotEmpty) return withSnapPrefix(fromLat, fromLng, pts);
    }
    final kakao = await fetchKakaoMobilityLeg(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    return kakao.points.isNotEmpty
        ? withSnapPrefix(fromLat, fromLng, kakao.points)
        : kakao.points;
  }

  /// 요청 출발점과 API가 반환한 첫 포인트가 10m 이상 떨어져 있으면 출발점을
  /// 맨 앞에 이어붙인다 (도로 스냅 지점과 실제 출발 위치 사이 끊김 방지).
  List<GeoPoint> withSnapPrefix(
    double fromLat,
    double fromLng,
    List<GeoPoint> pts,
  ) {
    if (pts.isEmpty) return pts;
    final snapDist = haversineDistanceM(
      fromLat,
      fromLng,
      pts.first.lat,
      pts.first.lng,
    );
    return snapDist > 10 ? [(lat: fromLat, lng: fromLng), ...pts] : pts;
  }

  // ── TMAP 보행자 API ────────────────────────────────────────────

  Future<List<GeoPoint>> fetchTmapLeg({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final key = AppEnv.tmapAppKey;
      if (key.isEmpty) return [];

      final bodyStr = [
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
            Uri.parse(
              'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
            ),
            headers: {
              'appKey': key,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('[TMAP] status=${res.statusCode}');
        return [];
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List?;
      if (features == null) return [];

      final points = <GeoPoint>[];
      for (final feature in features) {
        final geometry = (feature as Map)['geometry'] as Map?;
        if (geometry == null || geometry['type'] != 'LineString') continue;
        final coords = geometry['coordinates'] as List?;
        if (coords == null) continue;
        for (final c in coords) {
          points.add((
            lat: (c[1] as num).toDouble(),
            lng: (c[0] as num).toDouble(),
          ));
        }
      }
      return points;
    } catch (e) {
      debugPrint('[TMAP] error=$e');
      return [];
    }
  }

  // ── Kakao Mobility API (폴백) ──────────────────────────────────

  static const _emptyKakaoLeg = (
    points: <GeoPoint>[],
    guides: <RouteGuidePoint>[],
    distanceM: 0,
    durationSec: 0,
  );

  Future<
    ({
      List<GeoPoint> points,
      List<RouteGuidePoint> guides,
      int distanceM,
      int durationSec,
    })
  >
  fetchKakaoMobilityLeg({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final key = AppEnv.kakaoRestApiKey;
      if (key.isEmpty) return _emptyKakaoLeg;

      final uri = Uri.parse(
        '${AppConstants.kakaoMobilityBaseUrl}/waypoints/directions',
      );
      final res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'KakaoAK $key',
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

      if (res.statusCode != 200) return _emptyKakaoLeg;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _emptyKakaoLeg;
      final r = routes[0] as Map<String, dynamic>;
      if ((r['result_code'] as int? ?? -1) != 0) return _emptyKakaoLeg;

      final summary = r['summary'] as Map<String, dynamic>? ?? {};
      final distanceM = (summary['distance'] as num? ?? 0).toInt();
      final durationSec = (summary['duration'] as num? ?? 0).toInt();

      final points = <GeoPoint>[];
      final guides = <RouteGuidePoint>[];
      for (final section in (r['sections'] as List? ?? [])) {
        final s = section as Map;
        for (final road in (s['roads'] as List? ?? [])) {
          final vx = (road as Map)['vertexes'] as List? ?? [];
          for (var i = 0; i < vx.length - 1; i += 2) {
            points.add((
              lat: (vx[i + 1] as num).toDouble(),
              lng: (vx[i] as num).toDouble(),
            ));
          }
        }
        for (final guide in (s['guides'] as List? ?? [])) {
          final g = guide as Map;
          final loc = g['x'] != null && g['y'] != null
              ? (
                  lat: (g['y'] as num).toDouble(),
                  lng: (g['x'] as num).toDouble(),
                )
              : null;
          if (loc == null) continue;
          guides.add(
            RouteGuidePoint(
              lat: loc.lat,
              lng: loc.lng,
              guidance: g['guidance']?.toString() ?? '',
              type: (g['type'] as num?)?.toInt() ?? 11,
              distanceM: (g['distance'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
      return (
        points: points,
        guides: guides,
        distanceM: distanceM,
        durationSec: durationSec,
      );
    } catch (e) {
      debugPrint('[KakaoMobility] error=$e');
      return _emptyKakaoLeg;
    }
  }
}
