// 스팟 기반 생성 코스(Mode B "코스 생성") 알고리즘을 실행해 실제 도로를 따라가는
// GPX 파일로 내보낸다. 결과 파일을 안드로이드 스튜디오 에뮬레이터의
// Extended Controls > Location > Routes 탭에서 그대로 import해 재생하면,
// 실기기 GPS 없이도 이탈 감지·도착 판정·잔여거리 계산을 실제 도로 경로로 검증할 수 있다.
//
// 실행: flutter test test/mode_b_gpx_export/export_generated_course_gpx_test.dart
// (TMAP_APP_KEY/KAKAO_REST_API_KEY가 필요한 실제 네트워크 호출이 있어 CI 대상이 아님)
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neummuk_ver2/features/mode_b/domain/entities/spot_entity.dart';
import 'package:neummuk_ver2/features/mode_b/domain/services/mode_b_course_generator.dart';

import 'gpx_writer.dart';
import 'road_route_fetcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('생성 코스 → 도로 기반 GPX 내보내기', () async {
    await dotenv.load(fileName: '.env');

    // 출발지: 명동역 부근. 필요하면 실제 검색 결과 좌표로 바꿔서 사용할 것.
    const userLat = 37.5636;
    const userLng = 126.9827;
    const spots = <SpotEntity>[
      SpotEntity(
        id: 'namsan_tower', name: '남산서울타워',
        lat: 37.5512, lng: 126.9882,
        type: 'tourist_sight', source: 'kakao',
      ),
      SpotEntity(
        id: 'myeongdong_cathedral', name: '명동성당',
        lat: 37.5633, lng: 126.9877,
        type: 'culture', source: 'kakao',
      ),
      SpotEntity(
        id: 'namsangol', name: '남산골한옥마을',
        lat: 37.5598, lng: 126.9938,
        type: 'culture', source: 'kakao',
      ),
    ];

    final route = const ModeBCourseGenerator().generate(
      spots: spots,
      userLat: userLat,
      userLng: userLng,
      targetKcal: 400,
      transport: 'walk',
      weightKg: 65,
      forceAll: true, // 샘플 스팟 전부 포함
    );

    expect(route, isNotNull, reason: '코스 생성 실패 — 샘플 스팟/좌표를 확인할 것');
    expect(route!.waypoints, isNotEmpty);

    final roadPoints = await fetchGeneratedCourseRoadRoute(
      startLat: userLat,
      startLng: userLng,
      waypoints: route.waypoints,
    );
    expect(roadPoints.length, greaterThan(1),
        reason: 'TMAP_APP_KEY/KAKAO_REST_API_KEY가 .env에 있는지, 네트워크가 되는지 확인할 것');

    final gpxPoints = roadPoints.map((p) => GpxPoint(lat: p.lat, lng: p.lng)).toList();
    final landmarks = [
      const GpxLandmark(name: '출발지', lat: userLat, lng: userLng),
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
    print('waypoints=${route.waypoints.length}, roadPoints=${roadPoints.length}, '
        'distanceKm=${route.distanceKm}, kcal=${route.kcal}');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
