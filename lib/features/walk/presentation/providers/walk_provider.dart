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
    _prefs = await SharedPreferences.getInstance();

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
        autoRunOnBoot: false,
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
      'sex': profile.sex,
    });
  }

  void _writeProfileToPrefs(UserProfileEntity profile) {
    _prefs?.setDouble(kWalkProfileHeight, profile.heightCm);
    _prefs?.setDouble(kWalkProfileWeight, profile.weightKg);
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
