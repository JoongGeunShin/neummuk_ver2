import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';
import '../../../../core/services/live_kcal_tracker.dart';
import '../../domain/entities/route_result_entity.dart';

part 'mode_a_nav_provider.g.dart';

// SharedPreferences keys — route 지오메트리는 저장하지 않는다: 앱 재시작 복원 시
// ModeAState(mode_a_provider.dart)가 이미 갖고 있는 출발/도착/경유지/이동수단으로
// search()를 다시 호출해 TMAP/Kakao/ODsay로부터 동일한 경로를 재계산한다. 여기서는
// "안내 중이었다"는 사실과 진행 인덱스만 있으면 충분하다.
const kModeANavActive = 'mode_a_nav_active';
const kModeANavLegIdx = 'mode_a_nav_leg_idx';
const kModeANavTransitStepIdx = 'mode_a_nav_transit_step_idx';
const kModeANavElapsedKcal = 'mode_a_nav_elapsed_kcal';

class ModeANavState {
  const ModeANavState({
    this.isNavigating = false,
    this.currentLegIdx = 0,
    this.nearestPtIdx = 0,
    this.remainingDistanceM = 0,
    this.remainingSec = 0,
    this.isOffRoute = false,
    this.currentTransitStepIdx = 0,
    this.elapsedKcal = 0.0,
  });

  final bool isNavigating;

  /// 도보/자전거 구간(segmentPolylines) 인덱스. 대중교통은 currentTransitStepIdx를 쓴다.
  final int currentLegIdx;

  /// 현재 구간 폴리라인 내에서의 최근접점 인덱스.
  final int nearestPtIdx;
  final int remainingDistanceM;
  final int remainingSec;
  final bool isOffRoute;

  /// 대중교통 안내: 현재 진행 중인 subPath 단계 인덱스
  final int currentTransitStepIdx;

  /// 실측 GPS 속도 기반 실시간 누적 칼로리(도보/자전거 전용 — LiveKcalTracker).
  /// 대중교통 안내 중에는 갱신되지 않는다(구간 자체가 도보/차량이 섞여 있어 실측
  /// 페이스 트래킹이 무의미).
  final double elapsedKcal;

  String get remainingLabel => remainingDistanceM < 1000
      ? '${remainingDistanceM}m'
      : '${(remainingDistanceM / 1000).toStringAsFixed(1)}km';

  int get remainingMinutes => max(1, (remainingSec / 60).ceil());

  ModeANavState copyWith({
    bool? isNavigating,
    int? currentLegIdx,
    int? nearestPtIdx,
    int? remainingDistanceM,
    int? remainingSec,
    bool? isOffRoute,
    int? currentTransitStepIdx,
    double? elapsedKcal,
  }) {
    return ModeANavState(
      isNavigating: isNavigating ?? this.isNavigating,
      currentLegIdx: currentLegIdx ?? this.currentLegIdx,
      nearestPtIdx: nearestPtIdx ?? this.nearestPtIdx,
      remainingDistanceM: remainingDistanceM ?? this.remainingDistanceM,
      remainingSec: remainingSec ?? this.remainingSec,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      currentTransitStepIdx:
          currentTransitStepIdx ?? this.currentTransitStepIdx,
      elapsedKcal: elapsedKcal ?? this.elapsedKcal,
    );
  }
}

@Riverpod(keepAlive: true)
class ModeANav extends _$ModeANav {
  SharedPreferences? _prefs;
  LiveKcalTracker? _kcalTracker;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 실측 GPS 속도 기반 실시간 칼로리 트래커 — foreground 걸음 추적·Mode B 내비게이션과
  /// 동일한 공식(WalkCalculator.met() + kcalPerHourFromMet)을 쓴다.
  LiveKcalTracker _kcalTrackerFor(BodyMetrics metrics) => _kcalTracker ??=
      LiveKcalTracker(metrics: metrics, initialKcal: state.elapsedKcal);

  @override
  ModeANavState build() => const ModeANavState();

  void start(RouteResultEntity route) {
    double totalM;
    int initialSec;

    if (route.transport == 'transit') {
      totalM = route.distanceKm * 1000;
      // 대중교통은 ODsay가 준 실제 소요시간 사용 (거리/속도 추정 부정확)
      initialSec = route.durationSeconds;
    } else if (route.segmentDistancesM.isNotEmpty) {
      totalM = route.segmentDistancesM.fold(0.0, (a, b) => a + b);
      final speedMs = route.transport == 'bike' ? 4.17 : 1.25;
      initialSec = (totalM / speedMs).round();
    } else {
      totalM = 0;
      initialSec = 0;
    }

    _kcalTracker = null;
    state = ModeANavState(
      isNavigating: true,
      currentLegIdx: 0,
      nearestPtIdx: 0,
      remainingDistanceM: totalM.round(),
      remainingSec: initialSec,
      currentTransitStepIdx: 0,
      elapsedKcal: 0.0,
    );
    unawaited(_persist());
  }

  void stop() {
    _kcalTracker = null;
    state = const ModeANavState();
    unawaited(_clearPersist());
  }

  /// 도보/자전거 내비게이션 중 GPS 위치 업데이트마다 호출 — 실측 속도로 MET을
  /// 보간해 칼로리를 누적한다. updateFromRoad와 별도 메서드인 이유: 이동수단
  /// 진행률(거리·구간) 로직과 칼로리 로직을 분리해, 향후 대중교통에도 부분적으로
  /// 적용하는 등의 변경이 서로에게 영향을 주지 않게 한다.
  void updateKcal({
    required double lat,
    required double lng,
    required BodyMetrics metrics,
  }) {
    if (!state.isNavigating) return;
    final tracker = _kcalTrackerFor(metrics);
    tracker.onTick(DateTime.now(), lat, lng);
    state = state.copyWith(elapsedKcal: tracker.kcal);
    _persistProgressAsync();
  }

  /// 앱 강제종료 후 재실행 복원 — restore()는 persist하지 않는다(이미 저장된 값을
  /// 그대로 반영하는 것뿐이라 다시 쓸 필요가 없다).
  void restore(ModeANavState savedState) {
    _kcalTracker = null;
    state = savedState;
  }

  /// 도보/자전거 구간 진행 갱신 — Mode B `updateGeneratedFromRoad` 대응.
  /// mixin이 현재 구간(segmentPolylines[currentLegIdx]) 기준으로 계산한 도로 스냅
  /// 진행률을 그대로 반영해, 화면에 그려지는 경로와 도착/이탈 판정 기준을 통일한다.
  void updateFromRoad({
    required RouteResultEntity route,
    required int nearestPtIdx,
    required double distToRoadM,
    required double distToLegEndM,
    required double remainingSegM,
  }) {
    if (!state.isNavigating) return;
    final segs = route.segmentDistancesM;
    if (segs.isEmpty) return;

    var legIdx = state.currentLegIdx;
    final isOffRoute = distToRoadM > AppConstants.offRouteThresholdM;

    // 구간 끝(경유지/목적지) 50m 이내 도달 시 다음 구간으로 전진
    if (distToLegEndM < 50 && legIdx < segs.length - 1) {
      legIdx++;
    }

    double remM = remainingSegM;
    for (int i = legIdx + 1; i < segs.length; i++) {
      remM += segs[i];
    }

    final speedMs = route.transport == 'bike' ? 4.17 : 1.25;

    state = state.copyWith(
      currentLegIdx: legIdx,
      nearestPtIdx: nearestPtIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      isOffRoute: isOffRoute,
    );
    _persistProgressAsync();
  }

  /// 대중교통: 현재 위치가 현재 subPath 도보 구간에서 이탈했는지 여부.
  /// 탑승 구간(버스/지하철)에는 이탈 개념이 없으므로 항상 false로 둔다.
  void updateTransitStep({
    required RouteResultEntity route,
    required double lat,
    required double lng,
    double? distToRoadM,
  }) {
    if (!state.isNavigating) return;
    final steps = route.transitSteps;
    if (steps.isEmpty) return;

    final idx = _advanceTransitStep(
      lat,
      lng,
      steps,
      state.currentTransitStepIdx,
    );
    final step = steps[idx];
    final isOffRoute =
        step.isWalk &&
        distToRoadM != null &&
        distToRoadM > AppConstants.offRouteThresholdM;

    int remMin = 0;
    for (int s = idx; s < steps.length; s++) {
      remMin += steps[s].sectionTimeMin;
    }

    state = state.copyWith(
      currentTransitStepIdx: idx,
      remainingSec: remMin * 60,
      isOffRoute: isOffRoute,
    );
    _persistProgressAsync();
  }

  /// 현재 단계의 끝 지점 80m 이내 진입 시 다음 단계로 전진 (전진만, 후퇴 없음)
  int _advanceTransitStep(
    double lat,
    double lng,
    List<TransitStep> steps,
    int currentIdx,
  ) {
    if (currentIdx >= steps.length - 1) return currentIdx;
    final step = steps[currentIdx];
    if (step.endLat == null || step.endLng == null) return currentIdx;
    final d = _dist(lat, lng, step.endLat!, step.endLng!);
    return d < 80 ? currentIdx + 1 : currentIdx;
  }

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0, toRad = pi / 180;
    final dLat = (lat2 - lat1) * toRad;
    final dLng = (lng2 - lng1) * toRad;
    final cosLat = cos(lat1 * toRad);
    return r * sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }

  // ── Persistence ───────────────────────────────────────────────────
  // route 자체는 저장하지 않는다 — ModeAState(mode_a_provider.dart)가 이미 출발/도착/경유지/
  // 이동수단을 저장·복원하므로, 앱 재시작 시 그 값으로 search()를 다시 호출해 경로를
  // 재계산한다(Mode B의 생성 코스가 도로 좌표를 다시 fetch하는 것과 동일한 패턴).

  Future<void> _persist() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(kModeANavActive, true);
      await prefs.setInt(kModeANavLegIdx, state.currentLegIdx);
      await prefs.setInt(kModeANavTransitStepIdx, state.currentTransitStepIdx);
      await prefs.setDouble(kModeANavElapsedKcal, state.elapsedKcal);
    } catch (_) {}
  }

  void _persistProgressAsync() {
    _getPrefs().then((prefs) {
      prefs.setInt(kModeANavLegIdx, state.currentLegIdx);
      prefs.setInt(kModeANavTransitStepIdx, state.currentTransitStepIdx);
      prefs.setDouble(kModeANavElapsedKcal, state.elapsedKcal);
    }).ignore();
  }

  Future<void> _clearPersist() async {
    try {
      final prefs = await _getPrefs();
      for (final key in [
        kModeANavActive,
        kModeANavLegIdx,
        kModeANavTransitStepIdx,
        kModeANavElapsedKcal,
      ]) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  // ── Static restore ────────────────────────────────────────────────

  static Future<ModeANavState?> tryRestoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(kModeANavActive) ?? false;
      if (!active) return null;

      final legIdx = prefs.getInt(kModeANavLegIdx) ?? 0;
      final transitStepIdx = prefs.getInt(kModeANavTransitStepIdx) ?? 0;
      final elapsedKcal = prefs.getDouble(kModeANavElapsedKcal) ?? 0.0;

      return ModeANavState(
        isNavigating: true,
        currentLegIdx: legIdx,
        currentTransitStepIdx: transitStepIdx,
        elapsedKcal: elapsedKcal,
      );
    } catch (_) {
      return null;
    }
  }
}
