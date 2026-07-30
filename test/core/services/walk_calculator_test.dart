// WalkCalculator는 플랫폼 의존성 없는 순수 함수 모음이라 pedometer/geolocator/
// SharedPreferences 없이도 바로 검증 가능하다. MOVEMENT_CONVENTION.txt에 정의된
// 공식(보폭, MET 구간, 슬라이딩 윈도우 속도, 칼로리)이 그대로 구현돼 있는지 확인한다.
//
// 실행: flutter test test/core/services/walk_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:neummuk_ver2/core/constants/app_constants.dart';
import 'package:neummuk_ver2/core/models/body_metrics.dart';
import 'package:neummuk_ver2/core/services/walk_calculator.dart';

void main() {
  group('strideM', () {
    test('남성 계수 0.415 적용', () {
      expect(WalkCalculator.strideM(170.0, 'male'), closeTo(170.0 * 0.415 / 100.0, 1e-9));
    });

    test('여성 계수 0.413 적용', () {
      expect(WalkCalculator.strideM(160.0, 'female'), closeTo(160.0 * 0.413 / 100.0, 1e-9));
    });
  });

  test('distanceM = steps × strideM', () {
    expect(WalkCalculator.distanceM(1000, 0.7), closeTo(700.0, 1e-9));
  });

  group('met — 구간 경계 및 보간', () {
    test('0.0 ~ 1.0 km/h → 1.0 (정지)', () {
      expect(WalkCalculator.met(0.0), 1.0);
      expect(WalkCalculator.met(0.99), 1.0);
    });

    test('1.0 km/h 경계 → 걷기 구간 시작값 2.5', () {
      expect(WalkCalculator.met(1.0), closeTo(2.5, 1e-9));
    });

    test('걷기 구간(1.0~6.5) 중간값 선형 보간', () {
      // 3.75 km/h는 구간 중앙 → MET도 2.5~4.8의 중앙(3.65)이어야 함
      expect(WalkCalculator.met(3.75), closeTo(3.65, 1e-9));
    });

    test('6.5 km/h 경계 → 조깅 구간 시작값 6.0', () {
      expect(WalkCalculator.met(6.5), closeTo(6.0, 1e-9));
    });

    test('15.0 km/h 경계 → 자전거 구간 시작값 6.0', () {
      expect(WalkCalculator.met(15.0), closeTo(6.0, 1e-9));
    });

    test('25.0 km/h 이상 → 대중교통 1.5', () {
      expect(WalkCalculator.met(25.0), 1.5);
      expect(WalkCalculator.met(100.0), 1.5);
    });
  });

  group('activityType — 이동수단 자동 감지', () {
    test('속도 구간별 라벨', () {
      expect(WalkCalculator.activityType(0.5), 'sedentary');
      expect(WalkCalculator.activityType(3.0), 'walk');
      expect(WalkCalculator.activityType(5.0), 'walk_fast');
      expect(WalkCalculator.activityType(8.0), 'jog');
      expect(WalkCalculator.activityType(12.0), 'run');
      expect(WalkCalculator.activityType(20.0), 'bike');
      expect(WalkCalculator.activityType(30.0), 'transit');
    });
  });

  group('speedFromWindow', () {
    test('포인트 1개 이하면 0.0', () {
      expect(WalkCalculator.speedFromWindow([]), 0.0);
      expect(WalkCalculator.speedFromWindow([(DateTime(2026), 0.0)]), 0.0);
    });

    test('시간차 0이면 0.0', () {
      final t = DateTime(2026);
      expect(WalkCalculator.speedFromWindow([(t, 0.0), (t, 50.0)]), 0.0);
    });

    test('30초에 25m 이동 → 3.0 km/h', () {
      final start = DateTime(2026);
      final window = [
        (start, 0.0),
        (start.add(const Duration(seconds: 30)), 25.0),
      ];
      // (25m / 30s) × 3.6 = 3.0 km/h
      expect(WalkCalculator.speedFromWindow(window), closeTo(3.0, 1e-9));
    });
  });

  group('caloriesKcal — MET × (BMR/24) × 시간', () {
    const metrics = BodyMetrics(weightKg: 70.6, heightCm: 170.0, age: 30, sex: 'male');

    test('AppConstants.calculateKcalFromMet과 동일한 결과', () {
      const met = 3.65;
      const elapsed = Duration(seconds: 600);
      final expected = AppConstants.calculateKcalFromMet(
          met: met, metrics: metrics, durationSeconds: elapsed.inSeconds);
      expect(WalkCalculator.caloriesKcal(met, metrics, elapsed), closeTo(expected, 1e-9));
    });

    test('경과 시간 0이면 0kcal', () {
      expect(WalkCalculator.caloriesKcal(3.65, metrics, Duration.zero), 0.0);
    });
  });
}
