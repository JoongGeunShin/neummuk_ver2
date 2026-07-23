// Mode A(출발지→도착지, 최대 3개 경유지)의 실제 도로 경로를 가져와 안드로이드 스튜디오
// 에뮬레이터의 Extended Controls > Location > Routes 탭에서 재생 가능한 GPX로 내보낸다.
// mode_b_gpx_export와 동일한 목적 — 실기기 GPS 없이도 턴마커 소멸·회색 처리·이탈 감지·
// 자동 재경로를 검증할 수 있다. 아래 상수만 바꾸면 다른 출발/도착지·이동수단으로 테스트 가능.
//
// 실행: flutter test test/mode_a_gpx_export/export_route_gpx_test.dart
// (TMAP_APP_KEY/KAKAO_REST_API_KEY가 필요한 실제 네트워크 호출이 있어 CI 대상이 아님)
//
// 대중교통(ODsay)은 이 테스트에서 다루지 않는다 — ODsay 응답의 지하철/버스 구간 지오메트리
// 파싱은 mode_a_repository_impl.dart의 _getODsayRoute 내부에 있어 재사용하려면 리포지토리를
// 직접 호출해야 한다. 도보/자전거는 RoadRouteDatasource(공용 모듈)를 그대로 쓸 수 있어
// 여기서 직접 검증한다.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neummuk_ver2/core/utils/turn_point_utils.dart';
import 'package:neummuk_ver2/features/map/data/datasources/road_route_datasource.dart';

import '../mode_b_gpx_export/gpx_writer.dart';

// adb shell dumpsys location으로 확인한 에뮬레이터 실측 GPS를 넣을 것.
// 턴 마커 미표시 버그를 재현하려면 좌우회전이 실제로 있는(직선이 아닌) 경로로 바꿔서
// 테스트할 것 — 너무 짧거나 곧은 경로는 computeTurnPoints가 턴을 하나도 못 찾을 수 있다.
const _originLat = 37.465515;
const _originLng = 127.144647;
const _destLat = 37.471995;
const _destLng = 127.128597;

/// 경유지(선택) — 최대 3개, mode_a_provider의 RouteWaypoint와 동일한 순서 개념.
const _waypoints = <({double lat, double lng})>[];

/// 'walk' | 'bike'
const _transport = 'walk';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test는 기본적으로 HttpOverrides로 모든 네트워크 요청을 가로챈다.
  // 실제 네트워크가 필요한 이 테스트는 해제하고 진행한다.
  HttpOverrides.global = null;

  test('Mode A 도보/자전거 경로 → 도로 기반 GPX 내보내기', () async {
    await dotenv.load(fileName: '.env');

    const roadRoute = RoadRouteDatasource();

    final legs = [
      ..._waypoints,
      (lat: _destLat, lng: _destLng),
    ];

    final result = await roadRoute.fetchRouteWithFallback(
      startLat: _originLat,
      startLng: _originLng,
      waypoints: legs,
    );

    expect(result.source, isNotNull,
        reason: 'TMAP_APP_KEY/KAKAO_REST_API_KEY가 .env에 있는지, 네트워크가 되는지 확인할 것 '
            '(source가 null이면 TMAP·Kakao 둘 다 실패해 직선 폴백만 남았다는 뜻)');

    final allPoints = <GeoPoint>[];
    for (var i = 0; i < result.segments.length; i++) {
      final seg = result.segments[i];
      allPoints.addAll(i > 0 && allPoints.isNotEmpty ? seg.skip(1) : seg);
    }
    expect(allPoints.length, greaterThan(1),
        reason: '구간 폴리라인이 비어있음 — API 키/네트워크 확인');

    // 턴 마커 버그(도보/자전거 좌우회전 마커 미표시) 검증용 — 앱이 실제로 쓰는 것과
    // 동일한 computeTurnPoints를 그대로 돌려서, "턴 감지 자체가 안 됨"과 "감지는 됐는데
    // 지도에 안 그려짐"을 구분할 수 있게 한다.
    final turns = computeTurnPoints(
      allPoints.map((p) => (lat: p.lat, lng: p.lng)).toList(),
    );
    final realTurns = turns.where((t) => t.type != TurnType.arrival).toList();

    final gpxPoints = allPoints.map((p) => GpxPoint(lat: p.lat, lng: p.lng)).toList();
    final landmarks = [
      const GpxLandmark(name: '출발지', lat: _originLat, lng: _originLng),
      for (var i = 0; i < _waypoints.length; i++)
        GpxLandmark(name: '경유지 ${i + 1}', lat: _waypoints[i].lat, lng: _waypoints[i].lng),
      const GpxLandmark(name: '도착지', lat: _destLat, lng: _destLng),
      for (final t in realTurns)
        GpxLandmark(
          name: '${t.type.name} @ptIdx=${t.ptIdx}',
          lat: t.lat,
          lng: t.lng,
        ),
    ];

    final gpx = buildGpx(routeName: 'mode_a_$_transport', points: gpxPoints);

    final outDir = Directory('test/mode_a_gpx_export/output')..createSync(recursive: true);
    final outFile = File('${outDir.path}/${_transport}_route.gpx')..writeAsStringSync(gpx);

    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), greaterThan(0));

    // ignore: avoid_print
    print('GPX exported: ${outFile.absolute.path}');
    // ignore: avoid_print
    print('source=${result.source}, segments=${result.segments.length}, '
        'points=${allPoints.length}, guides=${result.guides.length}');
    // ignore: avoid_print
    print('턴 감지: ${realTurns.length}개 (경로 포인트 ${allPoints.length}개 중; '
        '0개면 이 경로엔 25° 이상 꺾이는 지점이 없다는 뜻 — 더 굴곡진 경로로 바꿔서 재시도할 것)');
    // ignore: avoid_print
    print('방문 순서 및 턴 위치:\n${describeLandmarks(landmarks)}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
