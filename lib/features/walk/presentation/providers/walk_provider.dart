import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/onboarding/domain/entities/user_profile_entity.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../../../features/record/data/repositories/record_repository_impl.dart';
import '../../../../features/record/domain/entities/daily_record_entity.dart';
import '../../../../features/record/presentation/providers/record_provider.dart';
import '../../domain/entities/walk_session_entity.dart';
import '../../domain/services/walk_calculator.dart';
import '../../domain/services/walk_task_handler.dart';

part 'walk_provider.g.dart';

@Riverpod(keepAlive: true)
class WalkSession extends _$WalkSession {
  Timer? _uiTicker;
  Timer? _stepDrip;

  SharedPreferences? _prefs;
  DateTime? _sessionStart;
  bool _initInFlight = false;

  // UI 드립 애니메이션용 표시 걸음 수 (trueSteps에 200ms마다 1씩 수렴)
  int _displaySteps = 0;

  DateTime _lastSyncTime = DateTime(0);
  final _recordRepo = RecordRepositoryImpl();

  UserProfileEntity _profile = const UserProfileEntity();

  @override
  WalkSessionEntity build() {
    ref.listen<UserProfileEntity>(
      userProfileProvider,
      (_, next) {
        _profile = next;
        _syncProfileToTask(next);
      },
      fireImmediately: true,
    );
    ref.onDispose(_cleanup);
    Future.microtask(_init);
    return const WalkSessionEntity();
  }

  Future<void> _init() async {
    // _sessionStart는 권한 요청(비동기) 이후에야 설정되므로, 그것만으로는 build()의
    // Future.microtask(_init)과 다른 호출부(예: 홈 화면 재시작 시 restart())가 거의 동시에
    // 들어오는 걸 막지 못한다 — 둘 다 이 값이 null인 상태로 통과해 Permission.request()를
    // 중복 호출하면 안드로이드가 "Can request only one set of permissions at a time"로
    // 하나를 취소시켜 PermissionRequestCancelledException이 던져진다. await 이전에 동기적으로
    // 세우는 이 플래그가 그 경합을 막는다.
    if (_sessionStart != null || _initInFlight) return;
    _initInFlight = true;
    try {
      _prefs = await SharedPreferences.getInstance();

      if (!(_prefs!.getBool(kWalkTrackingEnabled) ?? true)) {
        state = state.copyWith(trackingEnabled: false);
        return;
      }

      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return;

      _sessionStart = DateTime.now();

      // Foreground service가 onStart에서 읽을 수 있도록 먼저 기록
      _writeProfileToPrefs(_profile);

      await _startForegroundService();

      // 서비스 시작 직후 현재 프로필을 task isolate로 전송
      FlutterForegroundTask.sendDataToTask({
        'heightCm': _profile.heightCm,
        'weightKg': _profile.weightKg,
        'age': _profile.age,
        'sex': _profile.sex,
      });

      // 앱 재시작 시 이미 쌓인 걸음 수로 바로 초기화 — 0부터 드립하지 않음
      _displaySteps = _prefs!.getInt(kWalkTrueSteps) ?? 0;

      // 1초마다 task isolate 최신값을 reload 후 UI 갱신 + Firestore 동기화.
      // reload()가 없으면 main isolate의 SharedPreferences 캐시가 stale 상태로
      // 남아 알림과 홈화면의 수치가 다르게 보이는 버그가 발생한다.
      _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
        await _prefs?.reload();
        _emit();
        _maybeSync();
      });

      // 200ms마다 걸음 수를 1씩 드립해 신규 걸음만 카운터 애니메이션
      _stepDrip = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final trueSteps = _prefs?.getInt(kWalkTrueSteps) ?? 0;
        if (_displaySteps > trueSteps) {
          // 날짜 변경으로 리셋된 경우 즉시 0으로 맞춤
          _displaySteps = 0;
        } else if (_displaySteps < trueSteps) {
          _displaySteps++;
        }
        _emit();
      });
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> _startForegroundService() async {
    await FlutterForegroundTask.requestNotificationPermission();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'walk_tracking',
        channelName: '걷기 트래킹',
        channelDescription: '백그라운드에서 걷기를 추적하고 칼로리를 계산합니다.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 1초마다 onRepeatEvent 호출 — task isolate에서 칼로리 누적
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );

    await FlutterForegroundTask.startService(
      serviceId: 9001,
      notificationTitle: '내움먹 활동량',
      notificationText: '0걸음 · 0 kcal',
      callback: walkTaskEntryPoint,
    );
  }

  void _syncProfileToTask(UserProfileEntity profile) {
    _writeProfileToPrefs(profile);
    FlutterForegroundTask.sendDataToTask({
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'age': profile.age,
      'sex': profile.sex,
    });
  }

  void _writeProfileToPrefs(UserProfileEntity profile) {
    _prefs?.setDouble(kWalkProfileHeight, profile.heightCm);
    _prefs?.setDouble(kWalkProfileWeight, profile.weightKg);
    _prefs?.setInt(kWalkProfileAge, profile.age);
    _prefs?.setString(kWalkProfileSex, profile.sex);
  }

  void _emit() {
    if (_sessionStart == null) return;
    final p = _prefs;
    if (p == null) return;

    final distanceM = p.getDouble(kWalkDistanceM) ?? 0.0;
    final caloriesKcal = p.getDouble(kWalkCalories) ?? 0.0;
    final speedKmh = p.getDouble(kWalkSpeedKmh) ?? 0.0;
    final elapsed = DateTime.now().difference(_sessionStart!);

    state = WalkSessionEntity(
      steps: _displaySteps,
      distanceM: distanceM,
      caloriesKcal: caloriesKcal,
      speedKmh: speedKmh,
      elapsed: elapsed,
      isTracking: true,
      activityType: WalkCalculator.activityType(speedKmh),
    );
  }

  void _maybeSync() {
    final now = DateTime.now();
    if (now.difference(_lastSyncTime).inSeconds < 60) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final p = _prefs;
    if (p == null) return;
    _lastSyncTime = now;
    _recordRepo
        .saveDailyRecord(
          uid,
          DailyRecordEntity(
            date: _todayStr(),
            steps: p.getInt(kWalkTrueSteps) ?? 0,
            distanceM: p.getDouble(kWalkDistanceM) ?? 0.0,
            caloriesKcal: p.getDouble(kWalkCalories) ?? 0.0,
          ),
        )
        .then((_) => ref.invalidate(weekRecordsProvider));
  }

  /// 개인 설정 화면에서 백그라운드 추적 on/off를 전환한다.
  /// off로 전환하면 오늘 기록을 저장하고 Foreground Service를 정지한다 —
  /// 이렇게 명시적으로 stopService()를 호출해 두면 flutter_foreground_task가
  /// 기기를 "정상 종료" 상태로 기억해 재부팅 후에도 서비스가 다시 켜지지 않는다.
  Future<void> setTrackingEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    final current = _prefs!.getBool(kWalkTrackingEnabled) ?? true;
    if (enabled == current) return;
    await _prefs!.setBool(kWalkTrackingEnabled, enabled);

    if (enabled) {
      state = state.copyWith(trackingEnabled: true);
      if (_sessionStart == null) await _init();
    } else {
      await _cleanup();
      _sessionStart = null;
      state = const WalkSessionEntity(trackingEnabled: false);
    }
  }

  /// 로그인 이후 홈 화면 진입 시 호출 — 이미 추적 중이면 _init()의 가드로 아무 일도
  /// 하지 않으므로, 로그아웃 후 재로그인처럼 세션이 정지된 상태에서만 실제로 재시작한다.
  Future<void> restart() => _init();

  /// 로그아웃/회원탈퇴 시 호출 — 다음 계정에 이전 계정의 걸음 수·칼로리·신체 프로필이
  /// 그대로 노출되지 않도록 Foreground Service를 정지하고 로컬 캐시를 전부 지운다.
  Future<void> resetForLogout() async {
    await _cleanup();
    _sessionStart = null;
    _displaySteps = 0;

    final p = _prefs ??= await SharedPreferences.getInstance();
    for (final key in [
      kWalkDate,
      kWalkBaseline,
      kWalkCalories,
      kWalkTrueSteps,
      kWalkDistanceM,
      kWalkSpeedKmh,
      kWalkProfileHeight,
      kWalkProfileWeight,
      kWalkProfileAge,
      kWalkProfileSex,
      kWalkTrackingEnabled,
    ]) {
      await p.remove(key);
    }

    state = const WalkSessionEntity();
  }

  Future<void> _cleanup() async {
    _uiTicker?.cancel();
    _stepDrip?.cancel();
    _uiTicker = null;
    _stepDrip = null;

    final p = _prefs;
    final trueSteps = p?.getInt(kWalkTrueSteps) ?? 0;
    if (trueSteps > 0) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await _recordRepo.saveDailyRecord(
          uid,
          DailyRecordEntity(
            date: _todayStr(),
            steps: trueSteps,
            distanceM: p?.getDouble(kWalkDistanceM) ?? 0.0,
            caloriesKcal: p?.getDouble(kWalkCalories) ?? 0.0,
          ),
        );
      }
    }

    await FlutterForegroundTask.stopService();
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
