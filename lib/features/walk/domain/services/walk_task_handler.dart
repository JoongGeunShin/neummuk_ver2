import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';
import '../../../../core/services/walk_calculator.dart';

// SharedPreferences 키 — walk_provider.dart에서도 임포트해서 사용
const kWalkDate = 'walk_today_date';
const kWalkBaseline = 'walk_pedometer_baseline';
const kWalkCalories = 'walk_today_calories';
const kWalkTrueSteps = 'walk_today_steps';
const kWalkDistanceM = 'walk_today_distance_m';
const kWalkSpeedKmh = 'walk_today_speed_kmh';
const kWalkProfileHeight = 'walk_profile_height_cm';
const kWalkProfileWeight = 'walk_profile_weight_kg';
const kWalkProfileAge = 'walk_profile_age';
const kWalkProfileSex = 'walk_profile_sex';
const kWalkTrackingEnabled = 'walk_tracking_enabled';

/// Foreground Service 진입점 — vm:entry-point 없으면 tree-shaking으로 제거됨.
/// 이 isolate가 pedometer 구독 + 칼로리 계산 + 알림 갱신을 모두 담당하므로
/// 앱이 완전히 종료된 상태에서도 상태바 데이터가 계속 업데이트된다.
@pragma('vm:entry-point')
void walkTaskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(WalkTaskHandler());
}

class WalkTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepSub;
  SharedPreferences? _prefs;

  int? _baselineSteps;
  int _trueSteps = 0;
  double _distanceM = 0.0;
  double _speedKmh = 0.0;
  double _caloriesKcal = 0.0;

  // 앱이 SharedPreferences에 기록해 둔 프로필을 읽어 사용
  BodyMetrics _metrics = BodyMetrics.defaultMetrics;

  final _window = <(DateTime, double)>[];

  // 직전에 표시한 알림 텍스트 — 내용이 안 바뀌었으면 updateService()를 생략해
  // 매초 불필요한 시스템 알림 갱신 호출을 줄인다. 화면에 보이는 텍스트는 동일하므로
  // 체감 차이는 없다.
  String? _lastNotifText;

  // startForeground()가 알림을 NO_CLEAR로 "승격"시키기 전까지 약 1~2초의 틈이
  // 있는데, 그 틈에 사용자가 스와이프하면 지워진다(실기기 로그로 확인됨). 텍스트가
  // 그대로면 updateService()를 안 부르니 한 번 지워지면 다음 걸음이 늘 때까지
  // 영영 안 돌아올 수 있었다 — 텍스트 변화 여부와 무관하게 주기적으로 강제
  // 재게시해 짧은 시간 안에 스스로 복구되게 한다.
  int _ticksSinceNotifRefresh = 0;
  static const _forceNotifRefreshEverySec = 5;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _prefs = await SharedPreferences.getInstance();
    _loadProfile();
    _loadSavedState();

    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  /// 1초마다 호출 — 속도 재계산 + 칼로리 누적 + 알림 텍스트 갱신
  ///
  /// 슬라이딩 윈도우를 여기서도 prune해야 한다. 걷기를 멈추면 _onStep이
  /// 더 이상 호출되지 않아 윈도우가 만료되지 않고, 마지막 걷던 속도로
  /// 칼로리가 계속 누적되는 버그를 막는다.
  @override
  void onRepeatEvent(DateTime timestamp) {
    _pruneWindow(timestamp);
    _speedKmh = WalkCalculator.speedFromWindow(_window);
    _prefs?.setDouble(kWalkSpeedKmh, _speedKmh);

    if (_speedKmh >= 1.0) {
      _caloriesKcal += AppConstants.calculateKcalFromMet(
        met: WalkCalculator.met(_speedKmh),
        metrics: _metrics,
        durationSeconds: 1,
      );
      _prefs?.setDouble(kWalkCalories, _caloriesKcal);
    }

    // Mode B 네비게이션 중이면 안내 문구를 알림에 표시
    final navInstruction = _prefs?.getString('mode_b_nav_instruction');
    final notifText = (navInstruction != null && navInstruction.isNotEmpty)
        ? '🗺️ $navInstruction'
        : '$_trueSteps걸음 · ${_caloriesKcal.round()} kcal';

    _ticksSinceNotifRefresh++;
    final forceRefresh = _ticksSinceNotifRefresh >= _forceNotifRefreshEverySec;
    if (notifText != _lastNotifText || forceRefresh) {
      _lastNotifText = notifText;
      _ticksSinceNotifRefresh = 0;
      FlutterForegroundTask.updateService(notificationText: notifText);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _stepSub?.cancel();
    _stepSub = null;
  }

  /// 앱(main isolate)이 sendDataToTask로 보낸 프로필 업데이트를 수신
  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final h = (data['heightCm'] as num?)?.toDouble();
    final w = (data['weightKg'] as num?)?.toDouble();
    final a = (data['age'] as num?)?.toInt();
    final s = data['sex'] as String?;
    _metrics = BodyMetrics(
      heightCm: h ?? _metrics.heightCm,
      weightKg: w ?? _metrics.weightKg,
      age: a ?? _metrics.age,
      sex: s ?? _metrics.sex,
    );
    // 앱 재시작 시에도 프로필이 유지되도록 SharedPreferences에도 기록
    _prefs?.setDouble(kWalkProfileHeight, _metrics.heightCm);
    _prefs?.setDouble(kWalkProfileWeight, _metrics.weightKg);
    _prefs?.setInt(kWalkProfileAge, _metrics.age);
    _prefs?.setString(kWalkProfileSex, _metrics.sex);
  }

  void _loadProfile() {
    final p = _prefs!;
    _metrics = BodyMetrics(
      heightCm: p.getDouble(kWalkProfileHeight) ?? 170.0,
      weightKg: p.getDouble(kWalkProfileWeight) ?? 65.0,
      age: p.getInt(kWalkProfileAge) ?? 30,
      sex: p.getString(kWalkProfileSex) ?? 'male',
    );
  }

  void _loadSavedState() {
    final p = _prefs!;
    if (p.getString(kWalkDate) == _todayStr()) {
      _trueSteps = p.getInt(kWalkTrueSteps) ?? 0;
      _distanceM = p.getDouble(kWalkDistanceM) ?? 0.0;
      _caloriesKcal = p.getDouble(kWalkCalories) ?? 0.0;
      _speedKmh = p.getDouble(kWalkSpeedKmh) ?? 0.0;
    }
  }

  void _onStep(StepCount event) {
    final p = _prefs;
    if (p == null) return;

    final today = _todayStr();
    if (p.getString(kWalkDate) != today) {
      // 날짜가 바뀌면 모든 오늘 데이터 초기화
      _baselineSteps = event.steps;
      _trueSteps = 0;
      _distanceM = 0.0;
      _caloriesKcal = 0.0;
      _speedKmh = 0.0;
      _window.clear();
      p.setString(kWalkDate, today);
      p.setInt(kWalkBaseline, event.steps);
      p.remove(kWalkCalories);
      p.remove(kWalkTrueSteps);
      p.remove(kWalkDistanceM);
      p.remove(kWalkSpeedKmh);
    } else {
      _baselineSteps ??= p.getInt(kWalkBaseline) ?? event.steps;
      if (event.steps < _baselineSteps!) {
        _baselineSteps = event.steps;
        p.setInt(kWalkBaseline, event.steps);
      }
      _trueSteps = event.steps - _baselineSteps!;
    }

    final stride = WalkCalculator.strideM(_metrics.heightCm, _metrics.sex);
    _distanceM = WalkCalculator.distanceM(_trueSteps, stride);

    final now = DateTime.now();
    _window.add((now, _distanceM));
    _pruneWindow(now);
    _speedKmh = WalkCalculator.speedFromWindow(_window);

    p.setInt(kWalkTrueSteps, _trueSteps);
    p.setDouble(kWalkDistanceM, _distanceM);
    p.setDouble(kWalkSpeedKmh, _speedKmh);
  }

  void _pruneWindow(DateTime now) {
    final cutoff = now.subtract(const Duration(seconds: 30));
    _window.removeWhere((e) => e.$1.isBefore(cutoff));
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
