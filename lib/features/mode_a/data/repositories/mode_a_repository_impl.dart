import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';
import '../../../map/data/datasources/road_route_datasource.dart';
import '../../../map/domain/entities/place_entity.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/route_result_entity.dart';
import '../../domain/entities/waypoint_candidate_entity.dart';
import '../../domain/repositories/mode_a_repository.dart';

// ─── Mock fallback data ────────────────────────────────────────────────────────
// 실 API 실패 시 UI 테스트용 폴백
const _mockRestaurants = [
  RestaurantEntity(
    id: 'r1', name: '명동교자', menu: '칼국수', category: '한식',
    kcal: 520, distanceM: 120, walkMinutes: 2, rating: 4.6, reviewCount: 1284,
    latitude: 37.5636, longitude: 126.9869,
    kind: 'food', tags: ['관광객 픽', '단품'], imageType: 'noodle',
  ),
  RestaurantEntity(
    id: 'r2', name: '남산돈까스', menu: '왕돈까스', category: '경양식',
    kcal: 720, distanceM: 230, walkMinutes: 3, rating: 4.4, reviewCount: 882,
    latitude: 37.5640, longitude: 126.9875,
    kind: 'food', tags: ['든든', '리뷰 多'], imageType: 'pork',
  ),
  RestaurantEntity(
    id: 'r3', name: '회현참치김밥', menu: '참치김밥', category: '분식',
    kcal: 380, distanceM: 180, walkMinutes: 2, rating: 4.3, reviewCount: 421,
    latitude: 37.5630, longitude: 126.9860,
    kind: 'food', tags: ['가성비'], imageType: 'kimbap',
  ),
  RestaurantEntity(
    id: 'r4', name: '후암수제비', menu: '얼큰수제비', category: '한식',
    kcal: 460, distanceM: 310, walkMinutes: 4, rating: 4.5, reviewCount: 612,
    latitude: 37.5620, longitude: 126.9880,
    kind: 'food', tags: ['뜨끈'], imageType: 'soup',
  ),
  RestaurantEntity(
    id: 'r5', name: '남산 흑돼지', menu: '삼겹살(1인분)', category: '한식',
    kcal: 620, distanceM: 420, walkMinutes: 5, rating: 4.7, reviewCount: 1903,
    latitude: 37.5645, longitude: 126.9890,
    kind: 'food', tags: ['관광지', '저녁'], imageType: 'pork2',
  ),
  RestaurantEntity(
    id: 'r6', name: '더모스트커피', menu: '라떼+크로플', category: '카페',
    kcal: 410, distanceM: 150, walkMinutes: 2, rating: 4.5, reviewCount: 538,
    latitude: 37.5632, longitude: 126.9865,
    kind: 'cafe', tags: ['뷰맛집'], imageType: 'cafe',
  ),
];

/// Public for RestaurantDetailScreen mock lookup by id.
const mockRestaurants = _mockRestaurants;

class ModeARepositoryImpl implements ModeARepository {
  final _roadRoute = const RoadRouteDatasource();

  String get _kakaoKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';
  String get _odsayKey => dotenv.env['ODSAY_API_KEY'] ?? '';
  String get _tourApiKey => dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';

  // ────────────────────────────────────────────────────────────────────────────
  // getRoute
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<RouteResultEntity> getRoute({
    required String from,
    required String to,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    required String transport,
    required BodyMetrics metrics,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    // 좌표 없으면 mock 반환 (개발 초기 / GPS 없는 경우)
    if (originLat == null || originLng == null ||
        destLat == null || destLng == null) {
      return _mockRoute(from, to, transport, metrics, waypoints);
    }

    try {
      if (transport == 'transit') {
        return await _getODsayRoute(
          from: from, to: to,
          originLat: originLat, originLng: originLng,
          destLat: destLat, destLng: destLng,
          metrics: metrics, waypoints: waypoints,
        );
      } else {
        return await _getTmapWalkBikeRoute(
          from: from, to: to,
          originLat: originLat, originLng: originLng,
          destLat: destLat, destLng: destLng,
          transport: transport, metrics: metrics,
          waypoints: waypoints,
        );
      }
    } catch (e) {
      debugPrint('[ModeA] getRoute error: $e — falling back to mock');
      return _mockRoute(from, to, transport, metrics, waypoints);
    }
  }

  // ── 도보 / 자전거: TMAP 보행자 API (segment-by-segment) ─────────────────────

  Future<RouteResultEntity> _getTmapWalkBikeRoute({
    required String from,
    required String to,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String transport,
    required BodyMetrics metrics,
    required List<RouteWaypoint> waypoints,
  }) async {
    final legs = [
      ...waypoints.map((w) => (lat: w.latitude, lng: w.longitude)),
      (lat: destLat, lng: destLng),
    ];

    final result = await _roadRoute.fetchRouteWithFallback(
      startLat: originLat, startLng: originLng, waypoints: legs,
    );

    if (result.source == null) {
      debugPrint('[ModeA] TMAP/Kakao 도보·자전거 경로 모두 실패, mock 폴백');
      return _mockRoute(from, to, transport, metrics, waypoints);
    }

    final segmentPolylines = result.segments
        .map((seg) => seg.map((p) => LatLng(latitude: p.lat, longitude: p.lng)).toList())
        .toList();
    final segmentDistancesM = segmentPolylines.map(_polylineLengthM).toList();

    final routePoints = <LatLng>[];
    for (var i = 0; i < segmentPolylines.length; i++) {
      final seg = segmentPolylines[i];
      routePoints.addAll(i > 0 && routePoints.isNotEmpty ? seg.skip(1) : seg);
    }

    final distanceM = segmentDistancesM.fold(0.0, (a, b) => a + b);
    final distanceKm = double.parse((distanceM / 1000.0).toStringAsFixed(1));

    // 도보 4.5 km/h = 1.25 m/s, 자전거 15 km/h = 4.17 m/s
    final int durationSec = transport == 'walk'
        ? max(60, (distanceM / 1.25).round())
        : max(60, (distanceM / 4.17).round());

    final kcalBurn = AppConstants.calculateKcal(
      transport: transport,
      metrics: metrics,
      durationSeconds: durationSec,
    ).round();

    return RouteResultEntity(
      fromName: from,
      toName: to,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      transport: transport,
      kcalBurn: kcalBurn,
      waypoints: waypoints,
      routePoints: routePoints,
      // guides는 TMAP 경로일 땐 빈 리스트 — 방향 전환 안내는 기하 기반(turn_point_utils)으로
      // 오버레이 레이어에서 처리. Kakao 폴백일 때만 실제 guides가 채워진다.
      guides: result.guides
          .map((g) => RouteGuide(
                latitude: g.lat,
                longitude: g.lng,
                guidance: g.guidance,
                type: g.type,
                distanceM: g.distanceM,
              ))
          .toList(),
      segmentPolylines: segmentPolylines,
      segmentDistancesM: segmentDistancesM,
      routeSource: result.source,
    );
  }

  double _polylineLengthM(List<LatLng> pts) {
    double d = 0;
    for (int i = 1; i < pts.length; i++) {
      d += _haversine(pts[i - 1].latitude, pts[i - 1].longitude, pts[i].latitude, pts[i].longitude);
    }
    return d;
  }

  // ── 대중교통: ODsay 전체 실패 시 Kakao Mobility로 최종 폴백 ──────────────────
  // ODsay가 완전히 실패했을 때만 도달한다(경로 자체가 없거나 API 오류). 대중교통
  // 시간표 데이터가 아니므로 자동차 기준 경로를 근사치로 보여준다 — mock보다는
  // 실제 도로를 반영한 폴백이 낫다는 판단. 그래도 실패하면 mock으로 최종 폴백.
  Future<RouteResultEntity> _getKakaoFallbackForTransit({
    required String from,
    required String to,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required BodyMetrics metrics,
    required List<RouteWaypoint> waypoints,
  }) async {
    final kakao = await _roadRoute.fetchKakaoMobilityLeg(
      fromLat: originLat, fromLng: originLng, toLat: destLat, toLng: destLng,
    );
    if (kakao.points.isEmpty) {
      debugPrint('[ModeA] ODsay 실패 + Kakao 폴백도 실패, mock 폴백');
      return _mockRoute(from, to, 'transit', metrics, waypoints);
    }

    final routePoints =
        kakao.points.map((p) => LatLng(latitude: p.lat, longitude: p.lng)).toList();
    final distanceKm = double.parse((kakao.distanceM / 1000.0).toStringAsFixed(1));
    final durationSec = kakao.durationSec > 0 ? kakao.durationSec : max(60, kakao.distanceM ~/ 8);

    final kcalBurn = AppConstants.calculateKcal(
      transport: 'transit',
      metrics: metrics,
      durationSeconds: durationSec,
    ).round();

    return RouteResultEntity(
      fromName: from,
      toName: to,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      transport: 'transit',
      kcalBurn: kcalBurn,
      waypoints: waypoints,
      routePoints: routePoints,
      routeSource: 'kakao_fallback',
    );
  }

  // ── 대중교통: ODsay searchPubTransPathT ──────────────────────────────────────

  Future<RouteResultEntity> _getODsayRoute({
    required String from,
    required String to,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required BodyMetrics metrics,
    required List<RouteWaypoint> waypoints,
  }) async {
    final uri = Uri.parse('https://api.odsay.com/v1/api/searchPubTransPathT')
        .replace(queryParameters: {
      'SX': originLng.toString(),
      'SY': originLat.toString(),
      'EX': destLng.toString(),
      'EY': destLat.toString(),
      'apiKey': _odsayKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      debugPrint('[ModeA] ODsay ${response.statusCode}: ${response.body}');
      return _getKakaoFallbackForTransit(from: from, to: to, originLat: originLat, originLng: originLng, destLat: destLat, destLng: destLng, metrics: metrics, waypoints: waypoints);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error')) {
      debugPrint('[ModeA] ODsay error: ${json['error']}');
      return _getKakaoFallbackForTransit(from: from, to: to, originLat: originLat, originLng: originLng, destLat: destLat, destLng: destLng, metrics: metrics, waypoints: waypoints);
    }

    final result = json['result'] as Map<String, dynamic>?;
    if (result == null) return _getKakaoFallbackForTransit(from: from, to: to, originLat: originLat, originLng: originLng, destLat: destLat, destLng: destLng, metrics: metrics, waypoints: waypoints);

    final paths = result['path'] as List? ?? [];
    if (paths.isEmpty) return _getKakaoFallbackForTransit(from: from, to: to, originLat: originLat, originLng: originLng, destLat: destLat, destLng: destLng, metrics: metrics, waypoints: waypoints);

    final path = paths[0] as Map<String, dynamic>;
    final info = path['info'] as Map<String, dynamic>? ?? {};

    final totalTimeMin = (info['totalTime'] as num? ?? 0).toInt();
    final totalDistanceM = (info['totalDistance'] as num? ?? 0).toInt();
    final totalWalkM = (info['totalWalk'] as num? ?? 0).toInt();
    final durationSec = totalTimeMin * 60;
    final distanceKm = double.parse((totalDistanceM / 1000.0).toStringAsFixed(1));

    final subPaths = path['subPath'] as List? ?? [];

    // ── TMAP 도보 경로 pre-fetch: 첫 번째/마지막 도보 구간만 (최대 2회 호출) ──
    ({int idx, double sLat, double sLng, double eLat, double eLng})? firstWalk, lastWalk;

    for (int i = 0; i < subPaths.length; i++) {
      final sub = subPaths[i] as Map<String, dynamic>;
      if ((sub['trafficType'] as num? ?? 3).toInt() != 3) continue;

      double sLat = i == 0 ? originLat : (double.tryParse(sub['startY']?.toString() ?? '') ?? 0.0);
      double sLng = i == 0 ? originLng : (double.tryParse(sub['startX']?.toString() ?? '') ?? 0.0);
      double eLat = i == subPaths.length - 1 ? destLat : (double.tryParse(sub['endY']?.toString() ?? '') ?? 0.0);
      double eLng = i == subPaths.length - 1 ? destLng : (double.tryParse(sub['endX']?.toString() ?? '') ?? 0.0);

      // startX/Y 없으면 이전 구간 끝 좌표에서 유도 (대중교통 하차 직후 도보 구간에서 흔함)
      if (i != 0 && (sLat == 0.0 || sLng == 0.0)) {
        final r = _walkStartFromPrevSeg(subPaths, i);
        if (r != null) { sLat = r.lat; sLng = r.lng; }
      }

      // endX/Y 없으면 다음 구간 시작 좌표에서 유도
      if (eLat == 0.0 || eLng == 0.0) {
        final r = _walkEndFromNextSeg(subPaths, i);
        if (r != null) { eLat = r.lat; eLng = r.lng; }
      }

      if (sLat == 0.0 || sLng == 0.0 || eLat == 0.0 || eLng == 0.0) continue;
      final seg = (idx: i, sLat: sLat, sLng: sLng, eLat: eLat, eLng: eLng);
      firstWalk ??= seg;
      lastWalk = seg;
    }

    // info.mapObj: "BaseX:BaseY@ID:Class:StartIdx:EndIdx@..." — loadLane에 그대로 전달하면
    // ODsay가 각 버스·지하철 구간의 StartIdx~EndIdx만 잘라서 도로 형상을 반환함.
    // 없으면 subPath 데이터로 수동 구성 (passStopList.stations[n].index = 전체 노선 내 순번)
    final rawMapObj = info['mapObj'] as String?;
    // info.mapObj = "ID:Class:StartIdx:EndIdx@..." (BaseX:BaseY 접두사 없음)
    // loadLane mapObject = "BaseX:BaseY@ID:Class:StartIdx:EndIdx@..."이므로 0:0@ 붙임
    final mapObj = (rawMapObj != null && rawMapObj.isNotEmpty)
        ? '0:0@$rawMapObj'
        : _buildMapObj(subPaths);

    List<LatLng> firstWalkPts = const [], lastWalkPts = const [];
    // 버스·지하철 subPath 인덱스 → 도로 형상 좌표 목록
    final loadLaneResults = <int, List<LatLng>>{};

    final fetchFutures = <Future<void>>[];

    // TMAP 도보 경로
    if (firstWalk != null || lastWalk != null) {
      if (firstWalk != null && lastWalk != null && firstWalk.idx == lastWalk.idx) {
        fetchFutures.add(() async {
          firstWalkPts = await _fetchTmapWalkSegment(
              firstWalk!.sLat, firstWalk.sLng, firstWalk.eLat, firstWalk.eLng);
          lastWalkPts = firstWalkPts;
        }());
      } else {
        if (firstWalk != null) {
          fetchFutures.add(() async {
            firstWalkPts = await _fetchTmapWalkSegment(
                firstWalk!.sLat, firstWalk.sLng, firstWalk.eLat, firstWalk.eLng);
          }());
        }
        if (lastWalk != null) {
          fetchFutures.add(() async {
            lastWalkPts = await _fetchTmapWalkSegment(
                lastWalk!.sLat, lastWalk.sLng, lastWalk.eLat, lastWalk.eLng);
          }());
        }
      }
    }

    // loadLane: info.mapObj를 그대로 사용 — 구간 인덱스가 이미 포함되어 있어
    // 전체 노선이 아닌 승차~하차 구간 도로 형상만 반환됨
    if (mapObj != null && mapObj.isNotEmpty) {
      fetchFutures.add(() async {
        final allGeo = await _loadAllLaneGeometry(mapObj);
        // result.lane[] 순서 = subPaths 중 trafficType != 3 순서와 일치
        int laneIdx = 0;
        for (int i = 0; i < subPaths.length; i++) {
          final tt = ((subPaths[i] as Map<String, dynamic>)['trafficType'] as num? ?? 3).toInt();
          if (tt != 3) {
            if (laneIdx < allGeo.length) loadLaneResults[i] = allGeo[laneIdx];
            laneIdx++;
          }
        }
      }());
    }

    await Future.wait(fetchFutures);

    // ── subPath → routePoints + segmentPoints ─────────────────────────────────
    final routePoints = <LatLng>[];
    routePoints.add(LatLng(latitude: originLat, longitude: originLng));
    final segmentPoints = <List<LatLng>>[];

    for (int i = 0; i < subPaths.length; i++) {
      final sub = subPaths[i] as Map<String, dynamic>;
      final trafficType = (sub['trafficType'] as num? ?? 3).toInt();
      final segPts = <LatLng>[];

      if (trafficType == 3) {
        // 도보 구간: TMAP 실제 경로 우선, 없으면 출발지/도착지 기반 직선
        final tmapPts = (firstWalk != null && i == firstWalk.idx)
            ? firstWalkPts
            : (lastWalk != null && i == lastWalk.idx)
                ? lastWalkPts
                : const <LatLng>[];

        if (tmapPts.isNotEmpty) {
          segPts.addAll(tmapPts);
        } else {
          // 시작점: 첫 구간은 반드시 출발지 좌표 사용
          if (i == 0) {
            segPts.add(LatLng(latitude: originLat, longitude: originLng));
          } else {
            var sx = double.tryParse(sub['startX']?.toString() ?? '') ?? 0.0;
            var sy = double.tryParse(sub['startY']?.toString() ?? '') ?? 0.0;
            if (sx == 0 || sy == 0) {
              final r = _walkStartFromPrevSeg(subPaths, i);
              if (r != null) { sx = r.lng; sy = r.lat; }
            }
            if (sx != 0 && sy != 0) segPts.add(LatLng(latitude: sy, longitude: sx));
          }
          // 끝점: 마지막 구간은 반드시 도착지 좌표 사용
          if (i == subPaths.length - 1) {
            segPts.add(LatLng(latitude: destLat, longitude: destLng));
          } else {
            final ex = double.tryParse(sub['endX']?.toString() ?? '') ?? 0.0;
            final ey = double.tryParse(sub['endY']?.toString() ?? '') ?? 0.0;
            if (ex != 0 && ey != 0) {
              segPts.add(LatLng(latitude: ey, longitude: ex));
            } else {
              final r = _walkEndFromNextSeg(subPaths, i);
              if (r != null) segPts.add(LatLng(latitude: r.lat, longitude: r.lng));
            }
          }
        }
      } else {
        // ── 버스·지하철 구간 ────────────────────────────────────────────────────
        // 탑승 · 하차 좌표 먼저 확보 (클리핑에 공유)
        final passStopList = sub['passStopList'] as Map<String, dynamic>?;
        final allStations = passStopList?['stations'] as List? ?? [];

        var bLat = double.tryParse(sub['startY']?.toString() ?? '') ?? 0.0;
        var bLng = double.tryParse(sub['startX']?.toString() ?? '') ?? 0.0;
        var aLat = double.tryParse(sub['endY']?.toString() ?? '') ?? 0.0;
        var aLng = double.tryParse(sub['endX']?.toString() ?? '') ?? 0.0;
        if ((bLat == 0 || bLng == 0) && allStations.isNotEmpty) {
          final f = allStations.first as Map<String, dynamic>;
          bLat = double.tryParse(f['y']?.toString() ?? '') ?? 0.0;
          bLng = double.tryParse(f['x']?.toString() ?? '') ?? 0.0;
        }
        if ((aLat == 0 || aLng == 0) && allStations.isNotEmpty) {
          final l = allStations.last as Map<String, dynamic>;
          aLat = double.tryParse(l['y']?.toString() ?? '') ?? 0.0;
          aLng = double.tryParse(l['x']?.toString() ?? '') ?? 0.0;
        }
        final hasClipBounds =
            bLat != 0 && bLng != 0 && aLat != 0 && aLng != 0;

        // Tier 1: loadLane(info.mapObj) — ODsay가 StartIdx~EndIdx 기반으로
        //         승차~하차 구간 도로 형상만 잘라서 반환 → 클리핑 불필요
        final lanePts = loadLaneResults[i] ?? [];
        if (lanePts.length >= 2) {
          segPts.addAll(lanePts);
        }

        // Tier 2: passShape.linestring — loadLane 실패 시 폴백
        //         구간 형상을 주기도 하지만 전체 노선인 경우도 있으므로
        //         탑승/하차 좌표로 클리핑 시도; 클리핑 결과가 너무 적으면 raw 사용
        if (segPts.length < 5) {
          segPts.clear();
          final passShape = sub['passShape'] as Map<String, dynamic>?;
          final linestring = passShape?['linestring'] as String?;
          if (linestring != null && linestring.isNotEmpty) {
            final raw = <LatLng>[];
            for (final pair in linestring.trim().split(' ')) {
              final parts = pair.split(',');
              if (parts.length < 2) continue;
              final lng = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lng != null && lat != 0 && lng != 0) {
                raw.add(LatLng(latitude: lat, longitude: lng));
              }
            }
            if (raw.length >= 2) {
              if (hasClipBounds && raw.length >= 6) {
                final c = _clipPolylineToSegment(raw, bLat, bLng, aLat, aLng);
                segPts.addAll(c.length >= 5 ? c : raw);
              } else {
                segPts.addAll(raw);
              }
            }
          }
        }

        // Tier 3: 모든 경유 정류장 좌표 — 정류장 간 직선이지만 전체 직선보다 훨씬 정확
        if (segPts.length < 5) {
          segPts.clear();
          for (final st in allStations) {
            final stMap = st as Map<String, dynamic>;
            final x = double.tryParse(stMap['x']?.toString() ?? '');
            final y = double.tryParse(stMap['y']?.toString() ?? '');
            if (x != null && y != null && x != 0 && y != 0) {
              segPts.add(LatLng(latitude: y, longitude: x));
            }
          }
        }
        debugPrint('[Transit seg$i] type=$trafficType pts=${segPts.length} '
            '(lane=${lanePts.length})');
      }

      routePoints.addAll(segPts);
      segmentPoints.add(segPts);
    }

    routePoints.add(LatLng(latitude: destLat, longitude: destLng));

    final transitSteps = _extractTransitSteps(
        subPaths, originLat, originLng, destLat, destLng, segmentPoints);

    const walkSpeedMs = 1.25;
    final walkTimeSec = (totalWalkM / walkSpeedMs).round();
    final transitTimeSec = max(0, durationSec - walkTimeSec);

    final walkKcal = AppConstants.calculateKcal(
      transport: 'walk', metrics: metrics, durationSeconds: walkTimeSec);
    final transitKcal = AppConstants.calculateKcal(
      transport: 'transit', metrics: metrics, durationSeconds: transitTimeSec);

    return RouteResultEntity(
      fromName: from,
      toName: to,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      transport: 'transit',
      kcalBurn: (walkKcal + transitKcal).round(),
      waypoints: waypoints,
      routePoints: routePoints,
      transitSteps: transitSteps,
    );
  }

  // ── 도보 구간 시작점: 이전 구간 끝 좌표에서 유도 ─────────────────────────────
  // (_walkEndFromNextSeg의 대칭 — 대중교통 하차 직후 도보 구간은 ODsay가 startX/Y를
  // 비워서 응답하는 경우가 있어, 없으면 이전 subPath의 끝(하차 지점)에서 가져온다.)

  static ({double lat, double lng})? _walkStartFromPrevSeg(List subPaths, int walkIdx) {
    if (walkIdx == 0) return null;
    final prev = subPaths[walkIdx - 1] as Map<String, dynamic>;
    final px = double.tryParse(prev['endX']?.toString() ?? '') ?? 0.0;
    final py = double.tryParse(prev['endY']?.toString() ?? '') ?? 0.0;
    if (px != 0 && py != 0) return (lat: py, lng: px);
    final stops = (prev['passStopList'] as Map<String, dynamic>?)?['stations'] as List?;
    if (stops != null && stops.isNotEmpty) {
      final st = stops.last as Map<String, dynamic>;
      final sx = double.tryParse(st['x']?.toString() ?? '') ?? 0.0;
      final sy = double.tryParse(st['y']?.toString() ?? '') ?? 0.0;
      if (sx != 0 && sy != 0) return (lat: sy, lng: sx);
    }
    return null;
  }

  // ── 도보 구간 끝점: 다음 구간 시작 좌표에서 유도 ─────────────────────────────

  static ({double lat, double lng})? _walkEndFromNextSeg(List subPaths, int walkIdx) {
    if (walkIdx + 1 >= subPaths.length) return null;
    final next = subPaths[walkIdx + 1] as Map<String, dynamic>;
    final nx = double.tryParse(next['startX']?.toString() ?? '') ?? 0.0;
    final ny = double.tryParse(next['startY']?.toString() ?? '') ?? 0.0;
    if (nx != 0 && ny != 0) return (lat: ny, lng: nx);
    final stops = (next['passStopList'] as Map<String, dynamic>?)?['stations'] as List?;
    if (stops != null && stops.isNotEmpty) {
      final st = stops.first as Map<String, dynamic>;
      final sx = double.tryParse(st['x']?.toString() ?? '') ?? 0.0;
      final sy = double.tryParse(st['y']?.toString() ?? '') ?? 0.0;
      if (sx != 0 && sy != 0) return (lat: sy, lng: sx);
    }
    return null;
  }

  // ── ODsay loadLane (info.mapObj 방식) ────────────────────────────────────────
  // mapObj = "BaseX:BaseY@ID:Class:StartIdx:EndIdx@..." — searchPubTransPathT 응답의
  // result.path[n].info.mapObj 값을 그대로 전달하면, ODsay가 각 구간의
  // StartIdx~EndIdx 범위 도로 형상만 잘라 result.lane[] 배열로 반환함.
  // lane[k] 순서는 subPaths 중 trafficType != 3 (버스·지하철) 구간 순서와 일치.

  Future<List<List<LatLng>>> _loadAllLaneGeometry(String mapObj) async {
    try {
      if (_odsayKey.isEmpty) return [];
      debugPrint('[ODsay loadLane] mapObject=$mapObj');
      // queryParameters 방식은 @ 를 %40으로 인코딩해 -8 오류 유발 → 직접 URL 구성
      final url = 'https://api.odsay.com/v1/api/loadLane'
          '?mapObject=$mapObj&apiKey=$_odsayKey';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('[ODsay loadLane] ${res.statusCode}');
        return [];
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        debugPrint('[ODsay loadLane] error: ${json['error']}');
        return [];
      }
      final result = json['result'] as Map<String, dynamic>?;
      final laneList = result?['lane'] as List?;
      if (laneList == null || laneList.isEmpty) return [];

      final all = <List<LatLng>>[];
      for (final lane in laneList) {
        final laneMap = lane as Map<String, dynamic>;
        final pts = <LatLng>[];
        final sections = laneMap['section'] as List? ?? [];
        for (final section in sections) {
          final graphPos = (section as Map<String, dynamic>)['graphPos'] as List? ?? [];
          for (final pos in graphPos) {
            final posMap = pos as Map<String, dynamic>;
            final x = (posMap['x'] as num?)?.toDouble();
            final y = (posMap['y'] as num?)?.toDouble();
            if (x != null && y != null && x != 0 && y != 0) {
              pts.add(LatLng(latitude: y, longitude: x));
            }
          }
        }
        all.add(pts);
        debugPrint('[ODsay loadLane] lane pts=${pts.length}');
      }
      return all;
    } catch (e) {
      debugPrint('[ODsay loadLane] error: $e');
      return [];
    }
  }

  // ── TMAP 보행자 경로 (첫/마지막 도보 구간용) ──────────────────────────────────

  Future<List<LatLng>> _fetchTmapWalkSegment(
    double startLat, double startLng, double endLat, double endLng,
  ) async {
    final pts = await _roadRoute.fetchTmapLeg(
      fromLat: startLat, fromLng: startLng, toLat: endLat, toLng: endLng,
    );
    return pts.map((p) => LatLng(latitude: p.lat, longitude: p.lng)).toList();
  }

  // ── ODsay subPath → TransitStep 파싱 ─────────────────────────────────────────

  List<TransitStep> _extractTransitSteps(
    List subPaths,
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    List<List<LatLng>> segmentPoints,
  ) {
    final steps = <TransitStep>[];
    for (int i = 0; i < subPaths.length; i++) {
      final sub = subPaths[i] as Map<String, dynamic>;
      final trafficType = (sub['trafficType'] as num? ?? 3).toInt();
      final distanceM   = (sub['distance'] as num? ?? 0).toInt();
      final timeSec     = (sub['sectionTime'] as num? ?? 0).toInt();
      final startName   = sub['startName'] as String? ?? '';
      final endName     = sub['endName'] as String? ?? '';

      // 시작/끝 좌표
      double? startLat, startLng, endLat, endLng;
      final passStopList = sub['passStopList'] as Map<String, dynamic>?;
      if (passStopList != null) {
        final stations = passStopList['stations'] as List? ?? [];
        if (stations.isNotEmpty) {
          final first = stations.first as Map<String, dynamic>;
          final last  = stations.last  as Map<String, dynamic>;
          startLng = double.tryParse(first['x']?.toString() ?? '');
          startLat = double.tryParse(first['y']?.toString() ?? '');
          endLng   = double.tryParse(last['x']?.toString() ?? '');
          endLat   = double.tryParse(last['y']?.toString() ?? '');
        }
      }
      // 첫 단계 시작 = 출발지 좌표
      if (i == 0) { startLat = originLat; startLng = originLng; }
      // 마지막 단계 끝 = 도착지 좌표
      if (i == subPaths.length - 1) { endLat = destLat; endLng = destLng; }
      // 도보 단계인데 시작 좌표가 없으면(정류장 정보가 없는 하차 직후 도보 등) 이전
      // 구간 끝 좌표에서 유도 — 없으면 시작 마커가 아예 안 찍힘(nav_mixin.dart 참고)
      if (trafficType == 3 && i != 0 && startLat == null) {
        final r = _walkStartFromPrevSeg(subPaths, i);
        if (r != null) { startLat = r.lat; startLng = r.lng; }
      }

      // 버스/지하철 노선 정보
      String? lineInfo;
      if (trafficType == 2) {
        // 버스
        final lanes = sub['lane'] as List? ?? [];
        if (lanes.isNotEmpty) {
          final busNos = lanes
              .map((l) => (l as Map<String, dynamic>)['busNo']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .take(2)
              .join('/');
          if (busNos.isNotEmpty) lineInfo = '$busNos번';
        }
      } else if (trafficType == 1) {
        // 지하철
        final lanes = sub['lane'] as List? ?? [];
        if (lanes.isNotEmpty) {
          lineInfo = (lanes.first as Map<String, dynamic>)['name']?.toString();
        }
        lineInfo ??= sub['startName']?.toString();
      }

      // 정류장 수 (도보 이외)
      final stationCount = trafficType != 3
          ? ((passStopList?['stations'] as List?)?.length ?? 0)
          : 0;

      steps.add(TransitStep(
        trafficType:    trafficType,
        startName:      startName,
        endName:        endName,
        distanceM:      distanceM,
        sectionTimeMin: timeSec,
        lineInfo:       lineInfo,
        startLat:       startLat,
        startLng:       startLng,
        endLat:         endLat,
        endLng:         endLng,
        stationCount:   stationCount,
        stepPoints:     i < segmentPoints.length ? segmentPoints[i] : const [],
      ));
    }
    return steps;
  }

  // ── Mock fallback ─────────────────────────────────────────────────────────────

  RouteResultEntity _mockRoute(
    String from,
    String to,
    String transport,
    BodyMetrics metrics,
    List<RouteWaypoint> waypoints,
  ) {
    final extraSec = waypoints.length * 600;
    final extraKm = waypoints.length * 0.8;
    final durationSec = 2520 + extraSec;
    final distanceKm = 3.2 + extraKm;
    final kcalBurn = AppConstants.calculateKcal(
      transport: transport,
      metrics: metrics,
      durationSeconds: durationSec,
    ).round();
    return RouteResultEntity(
      fromName: from,
      toName: to,
      distanceKm: distanceKm,
      durationSeconds: durationSec,
      transport: transport,
      kcalBurn: kcalBurn,
      waypoints: waypoints,
      // routePoints 없음 → 지도에 폴리라인 그리지 않음
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // getNearbyRestaurants — Kakao Local FD6 + TourAPI 음식점 (contentTypeId=39)
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int targetKcal,
  }) async {
    try {
      final results = await _fetchKakaoFoodPlaces(
          latitude, longitude, (radiusKm * 1000).round());
      if (results.isEmpty) return _filterMockByKcal(targetKcal);
      return results;
    } catch (e) {
      debugPrint('[ModeA] getNearbyRestaurants error: $e');
      return _filterMockByKcal(targetKcal);
    }
  }

  Future<List<RestaurantEntity>> _fetchKakaoFoodPlaces(
    double lat,
    double lng,
    int radiusM,
  ) async {
    final response = await http
        .get(
          Uri.parse('${AppConstants.kakaoLocalBaseUrl}/search/category.json')
              .replace(queryParameters: {
            'category_group_code': 'FD6',
            'x': lng.toString(),
            'y': lat.toString(),
            'radius': radiusM.clamp(100, 20000).toString(),
            'size': '15',
            'sort': 'distance',
          }),
          headers: {'Authorization': 'KakaoAK $_kakaoKey'},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['documents'] as List? ?? [];

    return docs.map<RestaurantEntity?>((doc) {
      final x = double.tryParse(doc['x']?.toString() ?? '');
      final y = double.tryParse(doc['y']?.toString() ?? '');
      if (x == null || y == null || x == 0 || y == 0) return null;
      final name = (doc['place_name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final categoryName = doc['category_name'] as String? ?? '';
      final distanceM =
          int.tryParse(doc['distance']?.toString() ?? '0') ?? 0;
      final kcal = _estimateKcal(categoryName);

      return RestaurantEntity(
        id: 'kakao_${doc['id']}',
        name: name,
        menu: _extractLeafCategory(categoryName),
        category: _extractMainCategory(categoryName),
        kcal: kcal,
        distanceM: distanceM,
        walkMinutes: max(1, (distanceM / 80).ceil()), // 도보 ~80m/분
        rating: 0.0,
        reviewCount: 0,
        latitude: y,
        longitude: x,
        kind: _isKindCafe(categoryName) ? 'cafe' : 'food',
        imageType: _imageTypeFromCategory(categoryName),
        address: (doc['road_address_name'] as String? ?? '').isNotEmpty
            ? doc['road_address_name'] as String
            : doc['address_name'] as String?,
        tel: doc['phone'] as String?,
        kakaoPlaceId: doc['id'] as String?,
      );
    }).whereType<RestaurantEntity>().toList();
  }

  // ── 카테고리 기반 kcal 추정 ──────────────────────────────────────────────────

  static const _kcalTable = <String, int>{
    '한식': 520, '일식': 550, '중식': 600, '양식': 680, '동남아': 550,
    '분식': 380, '패스트푸드': 700, '치킨': 650, '피자': 720,
    '카페': 350, '베이커리': 400, '디저트': 350, '아이스크림': 280,
    '뷔페': 900, '고기': 700, '해물': 500, '채식': 400, '죽': 300,
  };

  static int _estimateKcal(String categoryName) {
    final lower = categoryName.toLowerCase();
    for (final entry in _kcalTable.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 500; // 기본값
  }

  static String _extractMainCategory(String categoryName) {
    // "음식점 > 한식 > 갈비/삼겹살" → "한식"
    final parts = categoryName.split('>').map((s) => s.trim()).toList();
    if (parts.length >= 2) return parts[1];
    if (parts.isNotEmpty) return parts[0];
    return '음식점';
  }

  static String _extractLeafCategory(String categoryName) {
    // "음식점 > 한식 > 갈비/삼겹살" → "갈비/삼겹살"
    final parts = categoryName.split('>').map((s) => s.trim()).toList();
    final last = parts.isNotEmpty ? parts.last : categoryName;
    if (last.isEmpty) return '식사';
    // 너무 길면 앞 15자 잘라냄
    return last.length > 15 ? '${last.substring(0, 15)}...' : last;
  }

  static bool _isKindCafe(String categoryName) {
    final lower = categoryName.toLowerCase();
    return lower.contains('카페') || lower.contains('커피') ||
        lower.contains('디저트') || lower.contains('베이커리');
  }

  static String _imageTypeFromCategory(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('카페') || lower.contains('커피')) return 'cafe';
    if (lower.contains('일식') || lower.contains('초밥') || lower.contains('스시')) {
      return 'sushi';
    }
    if (lower.contains('삼겹') || lower.contains('갈비') || lower.contains('고기')) {
      return 'pork2';
    }
    if (lower.contains('돈까스') || lower.contains('경양식')) return 'pork';
    if (lower.contains('국밥') || lower.contains('수제비') || lower.contains('탕')) {
      return 'soup';
    }
    if (lower.contains('김밥') || lower.contains('분식')) return 'kimbap';
    if (lower.contains('국수') || lower.contains('냉면') || lower.contains('칼국수')) {
      return 'noodle';
    }
    return 'generic';
  }

  List<RestaurantEntity> _filterMockByKcal(int targetKcal) {
    if (targetKcal <= 0) return List.of(_mockRestaurants);
    return _mockRestaurants.where((r) {
      final ratio = r.kcal / targetKcal;
      return ratio >= (1 - AppConstants.kcalMatchTolerancePct) &&
          ratio <= (1 + AppConstants.kcalMatchTolerancePct * 2);
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // getWaypointCandidates — TourAPI locationBasedList2 (관광지/레포츠)
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<WaypointCandidateEntity>> getWaypointCandidates({
    required double midLat,
    required double midLng,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required int extraKcalNeeded,
    required String transport,
    required BodyMetrics metrics,
  }) async {
    try {
      final results = await _fetchTourApiPlaces(midLat, midLng, 3000);
      if (results.isEmpty) return [];

      final baseDist = _haversine(originLat, originLng, destLat, destLng);
      final speedMs = transport == 'bike' ? 4.17 : 1.25;

      final candidates = results.map<WaypointCandidateEntity?>((item) {
        final lat = (item['mapy'] as num?)?.toDouble();
        final lng = (item['mapx'] as num?)?.toDouble();
        if (lat == null || lng == null || lat == 0 || lng == 0) return null;

        final contentId = item['contentid']?.toString() ?? '';
        final name = (item['title'] as String? ?? '').trim();
        if (name.isEmpty) return null;

        // 우회 거리 계산: dist(O→W) + dist(W→D) - dist(O→D)
        final detourM = max(
          0.0,
          _haversine(originLat, originLng, lat, lng) +
              _haversine(lat, lng, destLat, destLng) -
              baseDist,
        );

        final detourSec = (detourM / speedMs).round();
        final detourKm =
            double.parse((detourM / 1000.0).toStringAsFixed(1));
        final extraKcal = AppConstants.calculateKcal(
          transport: transport,
          metrics: metrics,
          durationSeconds: detourSec,
        ).round();

        final contentTypeId =
            (item['contenttypeid'] as num?)?.toInt() ?? 12;
        final category =
            contentTypeId == 28 ? '레포츠' : '관광지';

        return WaypointCandidateEntity(
          id: 'tour_$contentId',
          name: name,
          latitude: lat,
          longitude: lng,
          address: item['addr1'] as String?,
          imageUrl: (item['firstimage'] as String?)?.isNotEmpty == true
              ? item['firstimage'] as String
              : null,
          category: category,
          detourSec: detourSec,
          detourKm: detourKm,
          extraKcal: extraKcal,
        );
      }).whereType<WaypointCandidateEntity>().toList();

      // extraKcal이 목표에 가까운 순으로 정렬, 상위 5개 반환
      candidates.sort((a, b) =>
          (a.extraKcal - extraKcalNeeded).abs().compareTo(
                (b.extraKcal - extraKcalNeeded).abs(),
              ));
      return candidates.take(5).toList();
    } catch (e) {
      debugPrint('[ModeA] getWaypointCandidates error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTourApiPlaces(
    double lat,
    double lng,
    int radiusM,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final typeId in [
      AppConstants.touristSightContentTypeId,
      AppConstants.tourActivityContentTypeId,
    ]) {
      try {
        final uri = Uri.parse(
                '${AppConstants.tourApiBaseUrl}/locationBasedList2')
            .replace(queryParameters: {
          'serviceKey': _tourApiKey,
          'numOfRows': '10',
          'pageNo': '1',
          'MobileOS': 'AND',
          'MobileApp': 'neummuk',
          'mapX': lng.toString(),
          'mapY': lat.toString(),
          'radius': radiusM.toString(),
          'contentTypeId': typeId.toString(),
          '_type': 'json',
        });
        final res =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final body = json['response']?['body'] as Map<String, dynamic>?;
        final items = body?['items']?['item'] as List? ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) results.add(item);
        }
      } catch (e) {
        debugPrint('[ModeA] _fetchTourApiPlaces typeId=$typeId error: $e');
      }
    }
    return results;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // getNearbyPlaces — TourAPI locationBasedList2 (관광지·문화시설·축제·여행코스)
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<PlaceEntity>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int contentTypeId,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.tourApiBaseUrl}/locationBasedList2')
          .replace(queryParameters: {
        'serviceKey': _tourApiKey,
        'numOfRows': '20',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'neummuk',
        'mapX': longitude.toString(),
        'mapY': latitude.toString(),
        'radius': (radiusKm * 1000).clamp(100, 20000).toInt().toString(),
        'contentTypeId': contentTypeId.toString(),
        'arrange': 'E',
        '_type': 'json',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final body = json['response']?['body'] as Map<String, dynamic>?;
      final rawItems = body?['items']?['item'];
      final items = rawItems is List
          ? rawItems.cast<Map<String, dynamic>>()
          : rawItems is Map<String, dynamic>
              ? [rawItems]
              : <Map<String, dynamic>>[];
      return items.map<PlaceEntity?>((item) {
        final lat = double.tryParse(item['mapy']?.toString() ?? '');
        final lng = double.tryParse(item['mapx']?.toString() ?? '');
        if (lat == null || lng == null) return null;
        final id = item['contentid']?.toString() ?? '';
        final name = (item['title'] as String? ?? '').trim();
        if (name.isEmpty) return null;
        final img = item['firstimage'] as String? ?? '';
        return PlaceEntity(
          id: 'tour_$id',
          name: name,
          latitude: lat,
          longitude: lng,
          address: item['addr1'] as String?,
          imageUrl: img.isNotEmpty ? img : null,
          category: _contentTypeLabel(contentTypeId),
          source: PlaceSource.tourApi,
          contentTypeId: contentTypeId,
        );
      }).whereType<PlaceEntity>().toList();
    } catch (e) {
      debugPrint('[ModeA] getNearbyPlaces typeId=$contentTypeId error: $e');
      return [];
    }
  }

  static String _contentTypeLabel(int typeId) => switch (typeId) {
        12 => '관광지',
        14 => '문화시설',
        15 => '축제·행사',
        25 => '여행코스',
        _ => '기타',
      };

  // ────────────────────────────────────────────────────────────────────────────
  // getNearbyDurunubiCourses — 두루누비 courseList + 위치 기반 필터
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<TouristRouteEntity>> getNearbyDurunubiCourses({
    required double latitude,
    required double longitude,
    required BodyMetrics metrics,
  }) async {
    try {
      final uri =
          Uri.parse('${AppConstants.durunubiBaseUrl}/courseList').replace(
        queryParameters: {
          'ServiceKey': _tourApiKey,
          'MobileOS': 'ETC',
          'MobileApp': 'neummuk',
          'numOfRows': '100',
          'pageNo': '1',
          '_type': 'json',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final rawItems =
          json['response']?['body']?['items']?['item'];
      final items = rawItems is List
          ? rawItems.cast<Map<String, dynamic>>()
          : rawItems is Map<String, dynamic>
              ? [rawItems]
              : <Map<String, dynamic>>[];

      final withDist = <({TouristRouteEntity route, double distM})>[];
      for (final item in items) {
        final lat = _parseDouble(item['mapy']);
        final lng = _parseDouble(item['mapx']);
        if (lat == null || lng == null) continue;
        final route = _parseDurunubiItem(item, lat, lng, metrics);
        if (route == null) continue;
        withDist.add((route: route, distM: _haversine(latitude, longitude, lat, lng)));
      }
      withDist.sort((a, b) => a.distM.compareTo(b.distM));
      return withDist.take(10).map((e) => e.route).toList();
    } catch (e) {
      debugPrint('[ModeA] getNearbyDurunubiCourses error: $e');
      return [];
    }
  }

  TouristRouteEntity? _parseDurunubiItem(
      Map<String, dynamic> item, double lat, double lng, BodyMetrics metrics) {
    final name = (item['crsKorNm'] as String? ?? '').trim();
    if (name.isEmpty) return null;
    final distKm = _parseDouble(item['crsDstnc']) ?? 0.0;
    final durationHrs = _parseDouble(item['crsTotlRqrmHour']) ?? 1.0;
    final kcal =
        AppConstants.calculateKcal(transport: 'walk', metrics: metrics,
            durationSeconds: (durationHrs * 3600).round()).round();
    final levelRaw = item['crsLevel']?.toString() ?? '';
    final levelTag = switch (levelRaw) {
      '1' || '하' => '하',
      '2' || '중하' => '중하',
      '3' || '중' => '중',
      '4' || '중상' => '중상',
      '5' || '상' => '상',
      _ => '보통',
    };
    final imgs = [
      item['thumbImg'], item['imgUrl'],
      item['crsImgFileNm'], item['repFileNm'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return TouristRouteEntity(
      id: 'dur_${item['crsIdx'] ?? name}',
      name: name,
      distanceKm: distKm,
      durationMinutes: (durationHrs * 60).round(),
      kcal: kcal,
      type: '도보',
      tags: [levelTag],
      startLat: lat,
      startLng: lng,
      region: item['sigun'] as String?,
      gpxpath: item['gpxpath'] as String?,
      imageUrls: imgs,
    );
  }

  static double? _parseDouble(dynamic val) =>
      val == null ? null : double.tryParse(val.toString());

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    const toRad = pi / 180;
    final dLat = (lat2 - lat1) * toRad;
    final dLng = (lng2 - lng1) * toRad;
    final cosLat = cos(lat1 * toRad);
    return r *
        sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }

  // info.mapObj 없을 때 subPath 데이터로 loadLane mapObject 수동 구성
  // format: "0:0@routeID:class:startStopIdx:endStopIdx@..."
  // class: 1=버스, 2=지하철 (trafficType과 반대)
  static String? _buildMapObj(List subPaths) {
    final parts = <String>['0:0'];
    for (final sub in subPaths) {
      final subMap = sub as Map<String, dynamic>;
      final tt = (subMap['trafficType'] as num? ?? 3).toInt();
      if (tt == 3) continue;

      final lanes = subMap['lane'] as List? ?? [];
      if (lanes.isEmpty) continue;
      final lane = lanes.first as Map<String, dynamic>;

      final stations = (subMap['passStopList'] as Map<String, dynamic>?)?['stations'] as List? ?? [];
      final startIdx = stations.isNotEmpty
          ? (stations.first as Map<String, dynamic>)['index']?.toString() ?? '-1'
          : '-1';
      final endIdx = stations.isNotEmpty
          ? (stations.last as Map<String, dynamic>)['index']?.toString() ?? '-1'
          : '-1';

      if (tt == 2) {
        // 버스: class=1, busID 사용
        final busId = lane['busID']?.toString() ?? lane['busLocalBlID']?.toString();
        if (busId != null && busId.isNotEmpty) parts.add('$busId:1:$startIdx:$endIdx');
      } else {
        // 지하철: class=2, subwayCode 사용
        final code = lane['subwayCode']?.toString();
        if (code != null && code.isNotEmpty) parts.add('$code:2:$startIdx:$endIdx');
      }
    }
    return parts.length > 1 ? parts.join('@') : null;
  }

  // 전체 노선 좌표(pts)에서 승차점(start)~하차점(end)에 가장 가까운 인덱스를 찾아 클리핑
  static List<LatLng> _clipPolylineToSegment(
    List<LatLng> pts,
    double startLat, double startLng,
    double endLat,   double endLng,
  ) {
    if (pts.length < 2) return pts;

    int startIdx = 0; double startDist = double.infinity;
    int endIdx   = 0; double endDist   = double.infinity;

    for (int i = 0; i < pts.length; i++) {
      final ds = _haversine(startLat, startLng, pts[i].latitude, pts[i].longitude);
      final de = _haversine(endLat,   endLng,   pts[i].latitude, pts[i].longitude);
      if (ds < startDist) { startDist = ds; startIdx = i; }
      if (de < endDist)   { endDist   = de; endIdx   = i; }
    }

    if (startIdx == endIdx) return pts;

    final lo = startIdx < endIdx ? startIdx : endIdx;
    final hi = startIdx < endIdx ? endIdx   : startIdx;
    final segment = pts.sublist(lo, hi + 1);

    // 방향이 역순(승차가 하차보다 뒤쪽 인덱스)이면 뒤집기
    return startIdx > endIdx ? segment.reversed.toList() : segment;
  }
}
