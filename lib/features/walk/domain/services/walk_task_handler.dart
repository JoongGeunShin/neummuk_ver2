import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'walk_calculator.dart';

// SharedPreferences 키 — walk_provider.dart에서도 임포트해서 사용
const kWalkDate = 'walk_today_date';
const kWalkBaseline = 'walk_pedometer_baseline';
const kWalkCalories = 'walk_today_calories';
const kWalkTrueSteps = 'walk_today_steps';
const kWalkDistanceM = 'walk_today_distance_m';
const kWalkSpeedKmh = 'walk_today_speed_kmh';
const kWalkProfileHeight = 'walk_profile_height_cm';
const kWalkProfileWeight = 'walk_profile_weight_kg';
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
  double _heightCm = 170.0;
  double _weightKg = 65.0;
  String _sex = 'male';

  final _window = <(DateTime, double)>[];

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
      _caloriesKcal += WalkCalculator.met(_speedKmh) * _weightKg / 3600.0;
      _prefs?.setDouble(kWalkCalories, _caloriesKcal);
    }

    // Mode B 네비게이션 중이면 안내 문구를 알림에 표시
    final navInstruction = _prefs?.getString('mode_b_nav_instruction');
    final notifText = (navInstruction != null && navInstruction.isNotEmpty)
        ? '🗺️ $navInstruction'
        : '$_trueSteps걸음 · ${_caloriesKcal.round()} kcal';

    FlutterForegroundTask.updateService(notificationText: notifText);
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
    final s = data['sex'] as String?;
    if (h != null) _heightCm = h;
    if (w != null) _weightKg = w;
    if (s != null) _sex = s;
    // 앱 재시작 시에도 프로필이 유지되도록 SharedPreferences에도 기록
    _prefs?.setDouble(kWalkProfileHeight, _heightCm);
    _prefs?.setDouble(kWalkProfileWeight, _weightKg);
    _prefs?.setString(kWalkProfileSex, _sex);
  }

  void _loadProfile() {
    final p = _prefs!;
    _heightCm = p.getDouble(kWalkProfileHeight) ?? 170.0;
    _weightKg = p.getDouble(kWalkProfileWeight) ?? 65.0;
    _sex = p.getString(kWalkProfileSex) ?? 'male';
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

    final stride = WalkCalculator.strideM(_heightCm, _sex);
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
