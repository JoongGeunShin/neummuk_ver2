import 'dart:async';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/onboarding/domain/entities/user_profile_entity.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../domain/entities/walk_session_entity.dart';
import '../../domain/services/walk_calculator.dart';

part 'walk_provider.g.dart';

// SharedPreferences 키
const _kDate = 'walk_today_date';
const _kBaseline = 'walk_pedometer_baseline';

@Riverpod(keepAlive: true)
class WalkSession extends _$WalkSession {
  StreamSubscription<StepCount>? _stepSub;
  Timer? _ticker;
  SharedPreferences? _prefs;

  DateTime? _sessionStart;
  int? _baselineSteps;
  int _steps = 0;
  double _distanceM = 0.0;
  double _speedKmh = 0.0;

  // 30초 슬라이딩 윈도우: (시각, 누적 이동거리m)
  final _window = <(DateTime, double)>[];

  // userProfileProvider는 AutoDispose이므로 listen으로 캐싱
  UserProfileEntity _profile = const UserProfileEntity();

  @override
  WalkSessionEntity build() {
    // 프로필 변경 시 캐시 갱신 (keepAlive가 AutoDispose 리스너를 유지시킴)
    ref.listen<UserProfileEntity>(
      userProfileProvider,
      (_, next) => _profile = next,
      fireImmediately: true,
    );
    ref.onDispose(_cleanup);
    Future.microtask(_init);
    return const WalkSessionEntity();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    _sessionStart = DateTime.now();

    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {}, // 센서 미지원 기기 대비
      cancelOnError: false,
    );
    // 1초마다 elapsed 갱신
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _onStep(StepCount event) {
    final prefs = _prefs;
    if (prefs == null) return;

    final today = _todayStr();
    final savedDate = prefs.getString(_kDate) ?? '';

    if (savedDate != today) {
      // 날짜가 바뀐 경우 → 오늘 기준으로 베이스라인 리셋
      _baselineSteps = event.steps;
      _steps = 0;
      _distanceM = 0.0;
      _window.clear();
      prefs.setString(_kDate, today);
      prefs.setInt(_kBaseline, event.steps);
    } else {
      // 같은 날 → 저장된 베이스라인 복원 (앱 재시작 대응)
      _baselineSteps ??= prefs.getInt(_kBaseline) ?? event.steps;

      // 기기 재부팅 시 하드웨어 카운터가 리셋되므로 베이스라인 재설정
      if (event.steps < _baselineSteps!) {
        _baselineSteps = event.steps;
        prefs.setInt(_kBaseline, event.steps);
      }

      _steps = event.steps - _baselineSteps!;
    }

    final stride = WalkCalculator.strideM(_profile.heightCm, _profile.sex);
    _distanceM = WalkCalculator.distanceM(_steps, stride);

    final now = DateTime.now();
    _window.add((now, _distanceM));
    _pruneWindow(now);
    _speedKmh = WalkCalculator.speedFromWindow(_window);

    _emit();
  }

  void _emit() {
    if (_sessionStart == null) return;
    final elapsed = DateTime.now().difference(_sessionStart!);
    final metVal = WalkCalculator.met(_speedKmh);

    state = WalkSessionEntity(
      steps: _steps,
      distanceM: _distanceM,
      caloriesKcal:
          WalkCalculator.caloriesKcal(metVal, _profile.weightKg, elapsed),
      speedKmh: _speedKmh,
      elapsed: elapsed,
      isTracking: true,
      activityType: WalkCalculator.activityType(_speedKmh),
    );
  }

  void _pruneWindow(DateTime now) {
    final cutoff = now.subtract(const Duration(seconds: 30));
    _window.removeWhere((e) => e.$1.isBefore(cutoff));
  }

  void _cleanup() {
    _stepSub?.cancel();
    _ticker?.cancel();
    _stepSub = null;
    _ticker = null;
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
