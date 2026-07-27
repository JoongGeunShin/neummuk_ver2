// Mode A(출발지→도착지, 최대 3개 경유지)의 실제 도로 경로를 가져와 안드로이드 스튜디오
// 에뮬레이터의 Extended Controls > Location > Routes 탭에서 재생 가능한 GPX로 내보낸다.
// mode_b_gpx_export와 동일한 목적 — 실기기 GPS 없이도 턴마커 소멸·회색 처리·이탈 감지·
// 자동 재경로를 검증할 수 있다. 아래 상수만 바꾸면 다른 출발/경유/도착지·이동수단으로
// 테스트 가능.
//
// ModeARepositoryImpl.getRoute()를 앱과 동일하게 직접 호출한다 — 도보/자전거는 TMAP/Kakao,
// 대중교통은 ODsay를 그대로 타므로, 여기서 나오는 폴리라인·kcalBurn·distanceKm은 실제 앱
// 화면에 표시되는 값과 100% 동일하다.
//
// 실행: flutter test test/mode_a_gpx_export/export_route_gpx_test.dart
// (TMAP_APP_KEY/KAKAO_REST_API_KEY/ODSAY_API_KEY가 필요한 실제 네트워크 호출이 있어 CI 대상이 아님)
//
// 좌표를 실제 앱에서 그대로 가져오려면: 실기기/에뮬레이터에서 Mode A 코스를 생성할 때마다
// mode_a_provider.dart의 search()가 "[ModeA][gpx-test-input]" 로그로 origin/waypoints/dest/
// transport와 결과(kcalBurn 등)를 콘솔에 출력한다. 그 값을 그대로 복사해 아래 상수에
// 붙여넣으면 앱에서 실제로 그렸던 경로를 그대로 재현할 수 있다.
import 'dart:io';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neummuk_ver2/core/constants/app_constants.dart';
import 'package:neummuk_ver2/core/models/body_metrics.dart';
import 'package:neummuk_ver2/core/utils/turn_point_utils.dart';
import 'package:neummuk_ver2/features/mode_a/data/repositories/mode_a_repository_impl.dart';
import 'package:neummuk_ver2/features/mode_a/domain/entities/route_result_entity.dart';

import '../mode_b_gpx_export/gpx_writer.dart';

// adb shell dumpsys location으로 확인한 에뮬레이터 실측 GPS를 넣거나, 앱 콘솔의
// "[ModeA][gpx-test-input]" 로그에서 복사할 것.
// 턴 마커 미표시 버그를 재현하려면 좌우회전이 실제로 있는(직선이 아닌) 경로로 바꿔서
// 테스트할 것 — 너무 짧거나 곧은 경로는 computeTurnPoints가 턴을 하나도 못 찾을 수 있다.
const _originLat = 37.465515;
const _originLng = 127.144647;
const _destLat = 37.471995;
const _destLng = 127.128597;

/// 경유지(선택) — 최대 3개, mode_a_provider의 RouteWaypoint와 동일한 순서 개념.
const _waypoints = <({double lat, double lng})>[];

/// 'walk' | 'bike' | 'transit'
const _transport = 'walk';

/// kcalBurn 검증용 체성분 — 실제 사용자 값을 넣으면 앱 표시값과 그대로 대조 가능.
const _metrics = BodyMetrics(weightKg: 70.6, heightCm: 170.0, age: 30, sex: 'male');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test는 기본적으로 HttpOverrides로 모든 네트워크 요청을 가로챈다.
  // 실제 네트워크가 필요한 이 테스트는 해제하고 진행한다.
  HttpOverrides.global = null;

  test('Mode A 도보/자전거/대중교통 경로 → 도로 기반 GPX 내보내기 + kcal 검증', () async {
    await dotenv.load(fileName: '.env');

    final repo = ModeARepositoryImpl();
    final waypoints = [
      for (var i = 0; i < _waypoints.length; i++)
        RouteWaypoint(
          name: '경유지 ${i + 1}',
          latitude: _waypoints[i].lat,
          longitude: _waypoints[i].lng,
        ),
    ];

    final result = await repo.getRoute(
      from: '출발지',
      to: '도착지',
      originLat: _originLat,
      originLng: _originLng,
      destLat: _destLat,
      destLng: _destLng,
      transport: _transport,
      metrics: _metrics,
      waypoints: waypoints,
    );

    expect(result.routeSource, isNotNull,
        reason: 'TMAP_APP_KEY/KAKAO_REST_API_KEY/ODSAY_API_KEY가 .env에 있는지, 네트워크가 '
            '되는지 확인할 것 (routeSource가 null이면 전부 실패해 mock 폴백이 반환됐다는 뜻 — '
            'routePoints도 비어있음)');
    expect(result.routePoints.length, greaterThan(1),
        reason: '경로 폴리라인이 비어있음 — API 키/네트워크 확인');

    // ── kcal 계산 검증 ──────────────────────────────────────────────────────────
    // AppConstants.calculateKcal(MET × BMR/24 × 시간)을 독립적으로 재계산해 리포지토리가
    // 반환한 kcalBurn과 대조한다. 도보/자전거는 duration 전체가 단일 MET이라 정확히 같아야
    // 하고(다르면 리포지토리 쪽 duration/transport 전달에 버그가 있다는 뜻), 대중교통은
    // 도보 구간(MET 1.5가 아닌 walk MET)과 승차 구간(MET 1.5)이 섞여 있어 완전히 같지는
    // 않다 — 그 구성을 아래에서 별도로 출력해 확인한다.
    if (_transport == 'transit') {
      const walkSpeedMs = 1.25;
      final totalWalkM = result.transitSteps
          .where((s) => s.isWalk)
          .fold(0, (a, s) => a + s.distanceM);
      final walkTimeSec = (totalWalkM / walkSpeedMs).round();
      final transitTimeSec = max(0, result.durationSeconds - walkTimeSec);
      final walkKcal = AppConstants.calculateKcal(
          transport: 'walk', metrics: _metrics, durationSeconds: walkTimeSec);
      final transitKcal = AppConstants.calculateKcal(
          transport: 'transit', metrics: _metrics, durationSeconds: transitTimeSec);
      final expectedKcal = (walkKcal + transitKcal).round();
      // ignore: avoid_print
      print('kcal 재계산: walk(${walkTimeSec}s)=${walkKcal.toStringAsFixed(1)} + '
          'transit(${transitTimeSec}s)=${transitKcal.toStringAsFixed(1)} → '
          '$expectedKcal (앱 반환값=${result.kcalBurn})');
      // totalWalkM을 TransitStep(subPath) 합산으로 재구성하는 방식이라 ODsay가 자체
      // 집계하는 info.totalWalk와 반올림 경계에서 ±1~2 kcal 차이가 날 수 있어 근사 비교.
      expect(result.kcalBurn.toDouble(), closeTo(expectedKcal.toDouble(), 2),
          reason: '대중교통 kcal이 도보+승차 구간 분리 재계산과 크게 다름 — '
              '_getODsayRoute의 totalWalkM/durationSec 전달을 확인할 것');
    } else {
      final expectedKcal = AppConstants.calculateKcal(
        transport: _transport,
        metrics: _metrics,
        durationSeconds: result.durationSeconds,
      ).round();
      // ignore: avoid_print
      print('kcal 재계산: MET(${AppConstants.metValues[_transport]}) × '
          'BMR(${AppConstants.calculateBmr(_metrics).toStringAsFixed(1)}/24) × '
          '${result.durationSeconds}s → $expectedKcal (앱 반환값=${result.kcalBurn})');
      expect(result.kcalBurn, expectedKcal,
          reason: '$_transport kcal이 재계산값과 다름 — '
              '_getTmapWalkBikeRoute의 durationSec/transport 전달을 확인할 것');
    }

    final gpxPoints =
        result.routePoints.map((p) => GpxPoint(lat: p.latitude, lng: p.longitude)).toList();

    // 대중교통은 도로 형상이 이동수단마다 끊겨 있어 도보/자전거용 턴 감지가 무의미하므로
    // 대신 ODsay subPath(TransitStep)를 그대로 출력해 구간별 이동수단·정류장을 확인한다.
    final extraLandmarks = <GpxLandmark>[];
    if (_transport == 'transit') {
      // ignore: avoid_print
      print('대중교통 구간:');
      for (final step in result.transitSteps) {
        // ignore: avoid_print
        print('  [${step.typeLabel}] ${step.startName} → ${step.endName} '
            '(${step.distanceLabel}, ${step.sectionTimeMin}분'
            '${step.lineInfo != null ? ", ${step.lineInfo}" : ""})');
      }
    } else {
      // 턴 마커 버그(도보/자전거 좌우회전 마커 미표시) 검증용 — 앱이 실제로 쓰는 것과
      // 동일한 computeTurnPoints를 그대로 돌려서, "턴 감지 자체가 안 됨"과 "감지는 됐는데
      // 지도에 안 그려짐"을 구분할 수 있게 한다.
      final turns = computeTurnPoints(
        result.routePoints.map((p) => (lat: p.latitude, lng: p.longitude)).toList(),
      );
      final realTurns = turns.where((t) => t.type != TurnType.arrival).toList();
      extraLandmarks.addAll([
        for (final t in realTurns)
          GpxLandmark(name: '${t.type.name} @ptIdx=${t.ptIdx}', lat: t.lat, lng: t.lng),
      ]);
      // ignore: avoid_print
      print('턴 감지: ${realTurns.length}개 (경로 포인트 ${result.routePoints.length}개 중; '
          '0개면 이 경로엔 25° 이상 꺾이는 지점이 없다는 뜻 — 더 굴곡진 경로로 바꿔서 재시도할 것)');
    }

    final landmarks = [
      const GpxLandmark(name: '출발지', lat: _originLat, lng: _originLng),
      for (var i = 0; i < _waypoints.length; i++)
        GpxLandmark(name: '경유지 ${i + 1}', lat: _waypoints[i].lat, lng: _waypoints[i].lng),
      const GpxLandmark(name: '도착지', lat: _destLat, lng: _destLng),
      ...extraLandmarks,
    ];

    final gpx = buildGpx(routeName: 'mode_a_$_transport', points: gpxPoints);

    final outDir = Directory('test/mode_a_gpx_export/output')..createSync(recursive: true);
    final outFile = File('${outDir.path}/${_transport}_route.gpx')..writeAsStringSync(gpx);

    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), greaterThan(0));

    // ignore: avoid_print
    print('GPX exported: ${outFile.absolute.path}');
    // ignore: avoid_print
    print('source=${result.routeSource}, distanceKm=${result.distanceKm}, '
        'durationSec=${result.durationSeconds}, kcalBurn=${result.kcalBurn}, '
        'points=${result.routePoints.length}');
    // ignore: avoid_print
    print('방문 순서 및 턴 위치:\n${describeLandmarks(landmarks)}');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
