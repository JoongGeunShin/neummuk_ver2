// 실제 위치 기준으로 스팟을 검색하고(Kakao Local + TourAPI), Mode B "코스 생성" 알고리즘을
// 그대로 돌려서 실제 도로를 따라가는 GPX 파일로 내보낸다. 앱에서 사용자가 위치+목표 칼로리로
// 코스 생성을 눌렀을 때와 동일한 결과를 재현한다 — 아래 상수만 바꾸면 스팟을 손으로 고를 필요 없음.
// 결과 파일을 안드로이드 스튜디오 에뮬레이터의 Extended Controls > Location > Routes 탭에서
// 그대로 import해 재생하면, 실기기 GPS 없이도 이탈 감지·도착 판정·잔여거리 계산을 검증할 수 있다.
//
// 실행: flutter test test/mode_b_gpx_export/export_generated_course_gpx_test.dart
// (TMAP_APP_KEY/KAKAO_REST_API_KEY/TOUR_API_SERVICE_KEY가 필요한 실제 네트워크 호출이 있어 CI 대상이 아님)
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gpx_writer.dart';
import 'real_course_generator.dart';
import 'road_route_fetcher.dart';

// adb shell dumpsys location으로 확인한 에뮬레이터 실측 GPS (fused/gps 둘 다 동일):
// Location[gps 37.465385,127.144538 ...] — 반올림된 37.4654/127.1445와는 3~4m 차이가 나며,
// 밀집 도심에서는 이 정도로도 TMAP이 다른 골목으로 스냅해 경로 모양이 달라질 수 있다.
const _userLat = 37.465385;
const _userLng = 127.144538;
const _targetKcal = 330; // 마라탕으로 테스트
const _transport = 'walk';
const _weightKg = 70.6;

// 실제 앱은 도로 폴리라인을 가져올 때 course.startLat/startLng가 아니라 그 순간의
// 실시간 GPS(mode_b_mixin.dart의 _position)를 우선 쓴다 (_drawGeneratedCourseOnMap,
// _onStartModeBCourse 둘 다 `pos?.latitude ?? course.startLat!` 패턴). 코스 생성 시점과
// 폴리라인이 그려진 시점 사이 에뮬레이터 GPS가 조금이라도 다르면 구간별 도로 스냅이 달라져
// 경로 모양이 살짝 어긋난다 — 버그가 아니라 이 우선순위 때문. 앱에서 실제로 관찰한 좌표를
// 안다면 여기에 넣어서 그 순간을 그대로 재현할 것. 모르면 _userLat/_userLng와 동일하게 둘 것.
const _drawLat = _userLat;
const _drawLng = _userLng;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test는 기본적으로 HttpOverrides로 모든 네트워크 요청을 가짜 응답(빈 헤더의 400)으로
  // 가로챈다. TMAP/Kakao/TourAPI 실호출이 전부 이걸 맞고 조용히 실패해 직선 폴백만 남았던 원인이
  // 이거였다. 실제 네트워크가 필요한 이 테스트는 해제하고 진행한다.
  HttpOverrides.global = null;

  test('실제 위치 기준 생성 코스 → 도로 기반 GPX 내보내기', () async {
    await dotenv.load(fileName: '.env');

    final gen = RealCourseGenerator(weightKg: _weightKg);

    final spots = await gen.searchSpots(
      lat: _userLat,
      lng: _userLng,
      transport: _transport,
    );
    expect(spots, isNotEmpty,
        reason: 'KAKAO_REST_API_KEY/TOUR_API_SERVICE_KEY를 확인하거나, '
            '반경 내에 검색되는 스팟이 있는 좌표인지 확인할 것');

    final route = await gen.generateCourse(
      spots: spots,
      userLat: _userLat,
      userLng: _userLng,
      targetKcal: _targetKcal,
      transport: _transport,
    );
    expect(route, isNotNull, reason: '코스 생성 실패 — targetKcal이 반경 내 스팟으로 도달 가능한지 확인할 것');
    expect(route!.waypoints, isNotEmpty);

    final roadPoints = await fetchGeneratedCourseRoadRoute(
      startLat: _drawLat,
      startLng: _drawLng,
      waypoints: route.waypoints,
    );
    expect(roadPoints.length, greaterThan(1),
        reason: 'TMAP_APP_KEY/KAKAO_REST_API_KEY가 .env에 있는지, 네트워크가 되는지 확인할 것');

    final gpxPoints = roadPoints.map((p) => GpxPoint(lat: p.lat, lng: p.lng)).toList();
    final landmarks = [
      const GpxLandmark(name: '출발지', lat: _drawLat, lng: _drawLng),
      for (final wp in route.waypoints)
        if (wp.type != '출발지') GpxLandmark(name: wp.name, lat: wp.lat, lng: wp.lng),
    ];

    final gpx = buildGpx(routeName: route.name, points: gpxPoints, landmarks: landmarks);

    final outDir = Directory('test/mode_b_gpx_export/output')..createSync(recursive: true);
    final outFile = File('${outDir.path}/${route.id}.gpx')..writeAsStringSync(gpx);

    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), greaterThan(0));

    // ignore: avoid_print
    print('GPX exported: ${outFile.absolute.path}');
    // ignore: avoid_print
    print('spotsFound=${spots.length}, waypoints=${route.waypoints.length}, '
        'roadPoints=${roadPoints.length}, distanceKm=${route.distanceKm}, kcal=${route.kcal}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
