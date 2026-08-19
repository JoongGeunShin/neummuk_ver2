import 'dart:async';

import 'package:flutter/widgets.dart';
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
import '../../../../core/services/walk_calculator.dart';
import '../../domain/entities/walk_session_entity.dart';
import '../../domain/services/walk_task_handler.dart';

part 'walk_provider.g.dart';

@Riverpod(keepAlive: true)
class WalkSession extends _$WalkSession with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _cleanup();
    });
    Future.microtask(_init);
    return const WalkSessionEntity();
  }

  /// 앱 포그라운드/백그라운드 전환 감지.
  /// - resumed: 실제 OS 서비스 상태를 확인한 뒤 다시 시작 — "백그라운드 추적"을
  ///   꺼둔 사용자도 앱을 쓰는 동안엔 항상 추적되어야 한다.
  /// - paused/detached: 백그라운드 추적이 꺼져 있으면 정지 — 켜져 있으면 기존처럼
  ///   백그라운드에서도 계속 추적한다. inactive(짧은 전환 상태)는 무시해 깜빡임 방지.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        _reconcileAndInit();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        final bgAllowed = _prefs?.getBool(kWalkTrackingEnabled) ?? true;
        if (!bgAllowed && _sessionStart != null) _pauseTracking();
      default:
        break;
    }
  }

  /// 상태바 알림을 사용자가 직접 스와이프로 지우거나, OS가 배터리 최적화 등으로
  /// 서비스를 강제 종료시키면 실제 Foreground Service는 죽었는데 Dart 쪽
  /// _sessionStart는 여전히 non-null로 남는 "좀비 상태"가 생길 수 있다. 이 경우
  /// _sessionStart만 보고 판단하면 다시는 재시작되지 않는 버그가 생기므로, 앱이
  /// 다시 포그라운드로 올 때마다 실제 서비스 실행 여부를 물어보고 죽어있으면
  /// _sessionStart를 realign한 뒤 재시작한다.
  Future<void> _reconcileAndInit() async {
    if (_sessionStart != null) {
      final running = await FlutterForegroundTask.isRunningService;
      if (running) return;
      _sessionStart = null;
    }
    await _init();
  }

  /// 백그라운드 추적이 꺼진 상태로 앱이 백그라운드로 전환될 때 호출.
  /// 오늘 누적치는 SharedPreferences에 이미 남아있으므로, 다음 _init()이
  /// 그대로 이어서 시작한다(0부터 다시 세지 않음).
  Future<void> _pauseTracking() async {
    await _cleanup();
    _sessionStart = null;
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

      // kWalkTrackingEnabled는 "앱이 백그라운드로 가도 계속 추적할지"만 결정한다.
      // 앱이 포그라운드인 동안은 이 값과 무관하게 항상 추적을 시작한다 —
      // didChangeAppLifecycleState가 백그라운드 전환 시점에 이 값을 보고 정지 여부를 판단한다.
      state = state.copyWith(
        trackingEnabled: _prefs!.getBool(kWalkTrackingEnabled) ?? true,
      );

      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return;

      // Foreground service가 onStart에서 읽을 수 있도록 먼저 기록
      _writeProfileToPrefs(_profile);

      // _sessionStart는 서비스가 실제로 뜬 걸 확인한 뒤에만 세운다 — 예전엔 여기서
      // 먼저 세워뒀는데, startService()가 실패해도 예외를 던지지 않고
      // ServiceRequestFailure를 조용히 반환하기만 해서 그 실패를 못 잡아냈다.
      // 그 결과 _sessionStart는 "이미 추적 중"으로 영구히 잘못 표시되고, 이후
      // 모든 재시작 경로(resume, 토글 껐다 켜기)가 그 값만 보고 조기 return 해버려
      // 알림이 다시는 살아나지 않는 버그로 이어졌다.
      final started = await _startForegroundService();
      if (!started) return;
      _sessionStart = DateTime.now();

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

  /// 실제로 서비스가 떠 있는 상태가 됐는지(이미 떠 있었거나, 새로 띄우는 데
  /// 성공했으면 true)를 반환한다 — FlutterForegroundTask.startService()는 실패해도
  /// 예외를 던지지 않고 ServiceRequestFailure를 조용히 반환하기만 하므로, 호출부가
  /// 이 반환값을 반드시 확인해야 한다.
  Future<bool> _startForegroundService() async {
    await FlutterForegroundTask.requestNotificationPermission();

    if (await FlutterForegroundTask.isRunningService) {
      // 서비스(task isolate)는 살아있어도, 알림만 사용자가 스와이프로 지웠을 수
      // 있다. WalkTaskHandler.onRepeatEvent()는 알림 텍스트가 바뀔 때만
      // updateService()를 부르므로(불필요한 갱신 방지용 diff), 걸음 수가 그대로면
      // 지워진 알림이 영영 다시 안 뜬다. updateService()는 diff 없이 항상 네이티브
      // notify()를 다시 호출하므로, 여기서 한 번 강제로 불러 지워진 알림을 되살린다.
      final result = await FlutterForegroundTask.updateService(
        notificationText: '0걸음 · 0 kcal',
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[WalkSession] updateService(repost) failed: ${result.error}');
      }
      return true;
    }

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

    final result = await FlutterForegroundTask.startService(
      serviceId: 9001,
      notificationTitle: '내움먹 활동량',
      notificationText: '0걸음 · 0 kcal',
      callback: walkTaskEntryPoint,
    );

    if (result is ServiceRequestFailure) {
      debugPrint('[WalkSession] startService failed: ${result.error}');
      return false;
    }
    return true;
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

    // copyWith를 써야 한다 — 새 WalkSessionEntity(...)로 매번 새로 만들면 여기 안
    // 적은 필드(trackingEnabled)가 매초 기본값(true)으로 되돌아가, 백그라운드
    // 추적을 꺼도 1초 뒤 토글이 다시 켜진 것처럼 보이는 버그가 생긴다.
    state = state.copyWith(
      steps: _displaySteps,
      distanceM: distanceM,
      caloriesKcal: caloriesKcal,
      speedKmh: speedKmh,
      elapsed: elapsed,
      isTracking: true,
      activityType: WalkCalculator.activityType(speedKmh),
    );
  }

  /// Mode A/B 안내(자전거·대중교통)에서 나온 칼로리/거리를 홈 화면 "오늘" 총합에
  /// 병합한다. 도보는 이미 페도미터(WalkTaskHandler)가 실제 걸음을 세어 이 총합에
  /// 반영하고 있으므로 호출부(Mode A/B)에서 도보는 걸러내고 부른다 — 여기서 다시
  /// 더하면 같은 움직임이 두 번 계산된다. steps는 건드리지 않는다(자전거·대중교통은
  /// "걸음"이 아니므로).
  Future<void> addExternalKcal({
    required double kcal,
    required double distanceM,
  }) async {
    if (kcal <= 0 && distanceM <= 0) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.reload();

    final today = _todayStr();
    final sameDay = _prefs!.getString(kWalkDate) == today;
    final baseKcal = sameDay ? (_prefs!.getDouble(kWalkCalories) ?? 0.0) : 0.0;
    final baseDistanceM =
        sameDay ? (_prefs!.getDouble(kWalkDistanceM) ?? 0.0) : 0.0;
    final newKcal = baseKcal + kcal;
    final newDistanceM = baseDistanceM + distanceM;

    await _prefs!.setString(kWalkDate, today);
    await _prefs!.setDouble(kWalkCalories, newKcal);
    await _prefs!.setDouble(kWalkDistanceM, newDistanceM);

    if (_sessionStart != null) {
      _emit();
    } else {
      state = state.copyWith(caloriesKcal: newKcal, distanceM: newDistanceM);
    }
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

  /// 개인 설정 화면에서 "백그라운드 추적" on/off를 전환한다.
  /// 앱이 포그라운드인 동안은 이 값과 무관하게 계속 추적하므로, 여기서는 설정값만
  /// 갱신한다 — 실제 정지/재시작은 앱이 백그라운드로 전환될 때
  /// didChangeAppLifecycleState에서 처리한다.
  Future<void> setTrackingEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    final current = _prefs!.getBool(kWalkTrackingEnabled) ?? true;
    if (enabled == current) return;
    await _prefs!.setBool(kWalkTrackingEnabled, enabled);
    state = state.copyWith(trackingEnabled: enabled);
    if (enabled) await _reconcileAndInit();
  }

  /// 로그인 이후 홈 화면 진입 시 호출 — 이미 추적 중이면 아무 일도 하지 않으므로,
  /// 로그아웃 후 재로그인처럼 세션이 정지된 상태에서만 실제로 재시작한다.
  /// _reconcileAndInit()을 거치므로 서비스가 죽어있는 좀비 상태도 여기서 복구된다.
  Future<void> restart() => _reconcileAndInit();

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

    // stopService()를 Firestore 저장보다 먼저 호출해야 한다 — 네이티브 쪽은
    // ForegroundServiceStatus를 API_STOP으로 기록한 뒤에야 onTaskRemoved/onDestroy의
    // 재시작 알람(RestartReceiver, 1~5초 뒤 발동)을 건너뛴다. Firestore 저장을
    // 먼저 기다리면 앱이 막 백그라운드로 갈 때(네트워크 제약, 프로세스 freeze)
    // stopService()가 그 알람 발동 전에 실행될 기회를 놓쳐, 토글을 꺼도 알림이
    // 다시 살아나는 레이스가 생긴다.
    await FlutterForegroundTask.stopService();

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
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
