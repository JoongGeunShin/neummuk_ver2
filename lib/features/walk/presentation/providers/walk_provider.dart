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

// SharedPreferences 키 — 앱 재시작·강제종료 후에도 오늘 데이터를 복원하기 위해 사용
const _kDate = 'walk_today_date';      // 마지막으로 저장한 날짜 (yyyy-MM-dd)
const _kBaseline = 'walk_pedometer_baseline'; // 오늘 0보로 삼은 하드웨어 카운터값
const _kCalories = 'walk_today_calories';     // 오늘 소모 칼로리 누계 (kcal)

@Riverpod(keepAlive: true)
class WalkSession extends _$WalkSession {
  /// TYPE_STEP_COUNTER 센서 스트림 구독체.
  /// 하드웨어가 배치(6~10걸음)로 이벤트를 올리므로 UI 표시는 _stepDrip으로 보정.
  StreamSubscription<StepCount>? _stepSub;

  /// 1초 주기 타이머. 활동 중이면 칼로리 증분 후 emit.
  Timer? _elapsedTicker;

  /// 200ms 주기 타이머. _trueSteps에 뒤처진 _steps를 1씩 따라잡아
  /// 걸음 수가 한 걸음씩 올라가는 것처럼 보이게 한다.
  Timer? _stepDrip;

  SharedPreferences? _prefs;

  /// 앱이 이번에 열린 시각. elapsed(경과 시간) 표시에만 쓰인다.
  DateTime? _sessionStart;

  /// 오늘의 기준점이 되는 하드웨어 누적 걸음 카운터값.
  /// Android TYPE_STEP_COUNTER는 기기 부팅 이후 계속 증가하는 절대값이므로
  /// "오늘 0보"를 구하려면 오늘 처음 감지된 값을 빼야 한다.
  int? _baselineSteps;

  /// 센서에서 읽은 실제 오늘 걸음 수 (= event.steps - _baselineSteps).
  /// 거리·속도·칼로리 계산의 기준값이다.
  int _trueSteps = 0;

  /// UI에 표시되는 걸음 수. _stepDrip이 200ms마다 _trueSteps를 향해 1씩 증가시킨다.
  /// 앱 재시작 직후에는 _trueSteps와 즉시 동기화해 드립 없이 복원한다.
  int _steps = 0;

  /// 오늘 이동한 총 거리(미터). _trueSteps × 보폭으로 계산.
  double _distanceM = 0.0;

  /// 최근 30초 슬라이딩 윈도우로 계산한 현재 속도(km/h).
  /// 이동수단 자동 감지와 MET 계산에 사용된다.
  double _speedKmh = 0.0;

  /// 이전 앱 세션(앱을 껐다 켜기 전)까지 오늘 누적된 칼로리(kcal).
  /// _init() 시점에 SharedPreferences에서 읽어온다.
  double _savedCaloriesKcal = 0.0;

  /// 이번 앱 세션에서 새로 쌓인 칼로리(kcal).
  /// _elapsedTicker가 1초마다 MET × weightKg / 3600 을 더한다.
  /// 속도 < 1.0 km/h(정지)인 구간에서는 증가하지 않는다.
  double _sessionCaloriesKcal = 0.0;

  /// 속도 계산용 30초 슬라이딩 윈도우. (시각, 누적 이동거리m) 쌍의 리스트.
  /// _onStep마다 현재 포인트를 추가하고 30초 이전 항목을 제거한다.
  final _window = <(DateTime, double)>[];

  /// userProfileProvider는 AutoDispose라 직접 watch하면 keepAlive 범위 밖에서
  /// dispose될 수 있으므로 ref.listen으로 값을 캐싱해 사용한다.
  UserProfileEntity _profile = const UserProfileEntity();

  @override
  WalkSessionEntity build() {
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

    // 이전 세션 칼로리 복원 — 앱 강제종료 후에도 오늘 누계가 유지됨
    _savedCaloriesKcal = _prefs!.getDouble(_kCalories) ?? 0.0;
    _sessionStart = DateTime.now();

    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {}, // 센서 미지원 기기 대비
      cancelOnError: false,
    );

    // 1초마다 활동 중인 경우에만 칼로리 증분 후 emit
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_speedKmh >= 1.0) {
        _sessionCaloriesKcal +=
            WalkCalculator.met(_speedKmh) * _profile.weightKg / 3600.0;
      }
      _emit();
    });

    // 200ms마다 표시 걸음(_steps)을 실제 걸음(_trueSteps) 쪽으로 1씩 드립
    _stepDrip = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_steps < _trueSteps) {
        _steps++;
        _emit();
      }
    });
  }

  void _onStep(StepCount event) {
    final prefs = _prefs;
    if (prefs == null) return;

    final today = _todayStr();
    final savedDate = prefs.getString(_kDate) ?? '';

    if (savedDate != today) {
      // 날짜가 바뀐 경우 → 오늘 기준으로 베이스라인 리셋
      _baselineSteps = event.steps;
      _trueSteps = 0;
      _steps = 0;
      _distanceM = 0.0;
      _savedCaloriesKcal = 0.0;
      _sessionCaloriesKcal = 0.0;
      _window.clear();
      prefs.setString(_kDate, today);
      prefs.setInt(_kBaseline, event.steps);
      prefs.remove(_kCalories);
    } else {
      // 같은 날 → 저장된 베이스라인 복원 (앱 재시작 대응)
      _baselineSteps ??= prefs.getInt(_kBaseline) ?? event.steps;

      // 기기 재부팅 시 하드웨어 카운터가 리셋되므로 베이스라인 재설정
      if (event.steps < _baselineSteps!) {
        _baselineSteps = event.steps;
        prefs.setInt(_kBaseline, event.steps);
      }

      _trueSteps = event.steps - _baselineSteps!;
      // 앱 재시작 직후엔 _steps 도 동기화 (드립 없이 즉시 복원)
      if (_steps == 0) _steps = _trueSteps;
    }

    final stride = WalkCalculator.strideM(_profile.heightCm, _profile.sex);
    _distanceM = WalkCalculator.distanceM(_trueSteps, stride);

    final now = DateTime.now();
    _window.add((now, _distanceM));
    _pruneWindow(now);
    _speedKmh = WalkCalculator.speedFromWindow(_window);

    _emit();
  }

  void _emit() {
    if (_sessionStart == null) return;
    final elapsed = DateTime.now().difference(_sessionStart!);
    final totalCalories = _savedCaloriesKcal + _sessionCaloriesKcal;

    // 매 emit마다 prefs에 저장해 강제종료 시에도 데이터 손실 최소화
    _prefs?.setDouble(_kCalories, totalCalories);

    state = WalkSessionEntity(
      steps: _steps,
      distanceM: _distanceM,
      caloriesKcal: totalCalories,
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
    _elapsedTicker?.cancel();
    _stepDrip?.cancel();
    _stepSub = null;
    _elapsedTicker = null;
    _stepDrip = null;
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
