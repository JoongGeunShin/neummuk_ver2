import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/body_metrics.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/tourist_route_entity.dart';

part 'mode_b_nav_provider.g.dart';

// SharedPreferences keys
const kModeBNavActive = 'mode_b_nav_active';
const kModeBNavRouteJson = 'mode_b_nav_route_json';
const kModeBNavWaypointIdx = 'mode_b_nav_wp_idx';
const kModeBNavFoodKcal = 'mode_b_nav_food_kcal';
const kModeBNavFoodName = 'mode_b_nav_food_name';
const kModeBNavInstruction = 'mode_b_nav_instruction';
const kModeBNavElapsedKcal = 'mode_b_nav_elapsed_kcal';

class ModeBNavState {
  const ModeBNavState({
    this.isNavigating = false,
    this.route,
    this.currentWaypointIdx = 0,
    this.nearestGpxPtIdx = 0,
    this.remainingDistanceM = 0,
    this.remainingSec = 0,
    this.nextInstruction = '',
    this.isOffRoute = false,
    this.gpxPoints = const [],
    this.elapsedKcal = 0.0,
    this.foodKcal = 0,
    this.foodName = '',
    this.segmentDistancesM = const [],
  });

  final bool isNavigating;
  final TouristRouteEntity? route;
  final int currentWaypointIdx;
  final int nearestGpxPtIdx;
  final int remainingDistanceM;
  final int remainingSec;
  final String nextInstruction;
  final bool isOffRoute;
  final List<({double lat, double lng})> gpxPoints;
  final double elapsedKcal;
  final int foodKcal;
  final String foodName;
  /// 생성 코스 구간별 실제 도로 거리(m). segmentDistancesM[i] = 구간 i의 도로 거리
  final List<double> segmentDistancesM;

  String get remainingLabel => remainingDistanceM < 1000
      ? '${remainingDistanceM}m'
      : '${(remainingDistanceM / 1000).toStringAsFixed(1)}km';

  int get remainingMinutes => math.max(1, (remainingSec / 60).ceil());

  double get kcalProgress =>
      foodKcal > 0 ? (elapsedKcal / foodKcal).clamp(0.0, 1.0) : 0.0;

  /// GPX 코스이면서 gpxPoints가 아직 로드되지 않은 상태
  bool get needsGpxReload =>
      isNavigating &&
      !(route?.isGenerated ?? false) &&
      (route?.gpxpath?.isNotEmpty ?? false) &&
      gpxPoints.isEmpty;

  ModeBNavState copyWith({
    bool? isNavigating,
    TouristRouteEntity? route,
    int? currentWaypointIdx,
    int? nearestGpxPtIdx,
    int? remainingDistanceM,
    int? remainingSec,
    String? nextInstruction,
    bool? isOffRoute,
    List<({double lat, double lng})>? gpxPoints,
    double? elapsedKcal,
    int? foodKcal,
    String? foodName,
    List<double>? segmentDistancesM,
  }) =>
      ModeBNavState(
        isNavigating: isNavigating ?? this.isNavigating,
        route: route ?? this.route,
        currentWaypointIdx: currentWaypointIdx ?? this.currentWaypointIdx,
        nearestGpxPtIdx: nearestGpxPtIdx ?? this.nearestGpxPtIdx,
        remainingDistanceM: remainingDistanceM ?? this.remainingDistanceM,
        remainingSec: remainingSec ?? this.remainingSec,
        nextInstruction: nextInstruction ?? this.nextInstruction,
        isOffRoute: isOffRoute ?? this.isOffRoute,
        gpxPoints: gpxPoints ?? this.gpxPoints,
        elapsedKcal: elapsedKcal ?? this.elapsedKcal,
        foodKcal: foodKcal ?? this.foodKcal,
        foodName: foodName ?? this.foodName,
        segmentDistancesM: segmentDistancesM ?? this.segmentDistancesM,
      );
}

@Riverpod(keepAlive: true)
class ModeBNav extends _$ModeBNav {
  SharedPreferences? _prefs;
  DateTime? _lastUpdateTime;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  ModeBNavState build() => const ModeBNavState();

  Future<void> start({
    required TouristRouteEntity route,
    required List<({double lat, double lng})> gpxPoints,
    required int foodKcal,
    required String foodName,
    List<double> segmentDistancesM = const [],
  }) async {
    final isBike = route.type == '자전거';
    final speedMs = isBike ? 4.17 : 1.25;
    final totalM = _calcTotalDistanceM(route, gpxPoints, segmentDistancesM);
    final firstInstruction = _buildFirstInstruction(route);
    _lastUpdateTime = null;

    state = ModeBNavState(
      isNavigating: true,
      route: route,
      currentWaypointIdx: 0,
      nearestGpxPtIdx: 0,
      remainingDistanceM: totalM,
      remainingSec: (totalM / speedMs).round(),
      nextInstruction: firstInstruction,
      gpxPoints: gpxPoints,
      elapsedKcal: 0.0,
      foodKcal: foodKcal,
      foodName: foodName,
      segmentDistancesM: segmentDistancesM,
    );

    await _persist();
    _updateNotification(firstInstruction);
  }

  Future<void> stop() async {
    _lastUpdateTime = null;
    state = const ModeBNavState();
    await _clearPersist();
  }

  void restore(ModeBNavState savedState) {
    _lastUpdateTime = null;
    state = savedState;
  }

  void setGpxPoints(List<({double lat, double lng})> pts) {
    state = state.copyWith(gpxPoints: pts);
  }

  /// 앱 복원 후 도로 폴리라인 재계산 시 구간 거리 갱신
  void updateSegmentDistances(List<double> distancesM) {
    if (!state.isNavigating) return;
    state = state.copyWith(segmentDistancesM: distancesM);
  }

  void onPositionUpdate(double lat, double lng, BodyMetrics metrics, String transport) {
    if (!state.isNavigating) return;
    final route = state.route;
    if (route == null) return;

    // 실제 경과 시간(시간 단위)으로 칼로리 계산 → 이동 빈도 무관하게 정확
    final now = DateTime.now();
    final dtHours = _lastUpdateTime != null
        ? now.difference(_lastUpdateTime!).inMilliseconds / 3600000.0
        : 1.0 / 3600.0; // 첫 호출은 1초 가정
    _lastUpdateTime = now;

    // 이동 중일 때만 칼로리 누적 (1분 이상 경과는 GPS 끊김으로 보고 무시)
    final rate = AppConstants.kcalPerHour(
      transport: transport == 'bike' ? 'bike' : 'walk',
      metrics: metrics,
    );
    final newKcal = dtHours < (1.0 / 60.0)
        ? state.elapsedKcal + rate * dtHours
        : state.elapsedKcal;

    if (route.isGenerated && route.waypoints.isNotEmpty) {
      // 정상 흐름에서는 mixin이 도로 스냅 폴리라인 기준으로 계산해
      // updateGeneratedFromRoad를 직접 호출한다. 이 분기는 세그먼트 폴리라인이
      // 아직 준비되지 않은 예외적 상황에서만 도달하는 최소 폴백이다.
      state = state.copyWith(elapsedKcal: newKcal);
    } else if (state.gpxPoints.isNotEmpty) {
      _updateGpxNav(lat, lng, newKcal, transport);
    } else {
      state = state.copyWith(elapsedKcal: newKcal);
    }

    _updateNotification(state.nextInstruction);
    _persistProgressAsync();
  }

  /// 생성 코스 전용: 도로 스냅 폴리라인 기준으로 계산된 진행률을 반영한다.
  /// 화면에 그려지는 폴리라인(_segmentPolylines)과 동일한 데이터를 기준으로
  /// 도착/이탈/잔여거리를 판정해, 직선거리 기반 판정과의 불일치(오차)를 없앤다.
  void updateGeneratedFromRoad({
    required double distToTargetM,
    required double distToRoadM,
    required double remainingSegM,
    required BodyMetrics metrics,
    required String transport,
  }) {
    if (!state.isNavigating) return;
    final route = state.route;
    if (route == null || !route.isGenerated) return;

    final now = DateTime.now();
    final dtHours = _lastUpdateTime != null
        ? now.difference(_lastUpdateTime!).inMilliseconds / 3600000.0
        : 1.0 / 3600.0;
    _lastUpdateTime = now;

    final rate = AppConstants.kcalPerHour(
      transport: transport == 'bike' ? 'bike' : 'walk',
      metrics: metrics,
    );
    final newKcal = dtHours < (1.0 / 60.0)
        ? state.elapsedKcal + rate * dtHours
        : state.elapsedKcal;

    final wps = route.waypoints;
    var curIdx = state.currentWaypointIdx;

    if (curIdx >= wps.length) {
      state = state.copyWith(
        currentWaypointIdx: curIdx,
        remainingDistanceM: 0,
        remainingSec: 0,
        nextInstruction: '모든 스팟을 방문했어요! 🎉',
        elapsedKcal: newKcal,
        isOffRoute: false,
      );
      _updateNotification(state.nextInstruction);
      _persistProgressAsync();
      return;
    }

    final target = wps[curIdx];
    final isBike = transport == 'bike';
    final speedMs = isBike ? 4.17 : 1.25;
    final offRoute = distToRoadM > AppConstants.offRouteThresholdM;
    if (offRoute != state.isOffRoute) {
      debugPrint(offRoute
          ? '[ModeBNav] 이탈 감지: ${target.name} 구간에서 도로 기준 ${distToRoadM.round()}m 이탈'
          : '[ModeBNav] 이탈 해제: 경로 구간으로 복귀');
    }

    String instruction;
    final arrived = distToTargetM < 50;

    if (arrived) {
      curIdx++;
      if (curIdx < wps.length) {
        final next = wps[curIdx];
        final isNextOrigin = next.type == '출발지';
        instruction = isNextOrigin
            ? '${target.name} 도착! ➡ 출발지로 귀환'
            : '${target.name} 도착! ➡ ${next.name}으로 이동';
      } else {
        final isOriginReturn = target.type == '출발지';
        instruction = isOriginReturn ? '출발지 귀환 완료! 🎉' : '${target.name} 도착! 코스 완료 🎉';
      }
    } else {
      final distLabel = distToTargetM < 1000
          ? '${distToTargetM.round()}m'
          : '${(distToTargetM / 1000).toStringAsFixed(1)}km';
      final isOrigin = target.type == '출발지';
      instruction = isOrigin ? '출발지까지 $distLabel' : '${target.name}까지 $distLabel';
    }

    // 현재 목표 유지 시: 이번 틱에 계산된 도로 잔여거리 사용.
    // 방금 도착해 목표가 바뀐 틱에서는 새 구간의 사전계산 도로거리(segmentDistancesM)로
    // 근사하고, 다음 틱부터 도로 폴리라인 기준으로 정확히 갱신된다.
    final segs = state.segmentDistancesM;
    double remM = curIdx == state.currentWaypointIdx
        ? remainingSegM
        : (curIdx < segs.length ? segs[curIdx] : remainingSegM);
    if (segs.isNotEmpty) {
      for (int i = curIdx + 1; i < wps.length && i < segs.length; i++) {
        remM += segs[i];
      }
    } else {
      for (int i = curIdx; i < wps.length - 1; i++) {
        remM += _dist(wps[i].lat, wps[i].lng, wps[i + 1].lat, wps[i + 1].lng);
      }
    }

    state = state.copyWith(
      currentWaypointIdx: curIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      nextInstruction: instruction,
      isOffRoute: offRoute,
      elapsedKcal: newKcal,
    );

    _updateNotification(state.nextInstruction);
    _persistProgressAsync();
  }

  void _updateGpxNav(double lat, double lng, double newKcal, String transport) {
    final pts = state.gpxPoints;
    if (pts.isEmpty) return;

    final searchEnd = math.min(pts.length, state.nearestGpxPtIdx + 200);
    int bestIdx = state.nearestGpxPtIdx;
    double bestDist = double.infinity;

    for (int i = state.nearestGpxPtIdx; i < searchEnd; i++) {
      final d = _dist(lat, lng, pts[i].lat, pts[i].lng);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    double remM = 0;
    for (int i = bestIdx; i < pts.length - 1; i++) {
      remM += _dist(pts[i].lat, pts[i].lng, pts[i + 1].lat, pts[i + 1].lng);
    }

    final isBike = transport == 'bike';
    final speedMs = isBike ? 4.17 : 1.25;
    final isNearEnd = bestIdx >= pts.length - 10;
    final offRoute = bestDist > AppConstants.offRouteThresholdM;

    state = state.copyWith(
      nearestGpxPtIdx: bestIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      nextInstruction: isNearEnd ? '코스 종점에 거의 다 왔어요!' : '경로를 따라 계속 이동하세요',
      isOffRoute: offRoute,
      elapsedKcal: newKcal,
    );
  }

  // ── Persistence ───────────────────────────────────────────────────

  Future<void> _persist() async {
    final route = state.route;
    if (route == null) return;
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(kModeBNavActive, true);
      await prefs.setString(kModeBNavRouteJson, jsonEncode(route.toJson()));
      await prefs.setInt(kModeBNavFoodKcal, state.foodKcal);
      await prefs.setString(kModeBNavFoodName, state.foodName);
    } catch (_) {}
  }

  void _persistProgressAsync() {
    _getPrefs().then((prefs) {
      prefs.setInt(kModeBNavWaypointIdx, state.currentWaypointIdx);
      prefs.setDouble(kModeBNavElapsedKcal, state.elapsedKcal);
    }).ignore();
  }

  Future<void> _clearPersist() async {
    try {
      final prefs = await _getPrefs();
      for (final key in [
        kModeBNavActive, kModeBNavRouteJson, kModeBNavWaypointIdx,
        kModeBNavFoodKcal, kModeBNavFoodName, kModeBNavInstruction,
        kModeBNavElapsedKcal,
      ]) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  void _updateNotification(String text) {
    _getPrefs()
        .then((p) => p.setString(kModeBNavInstruction, text))
        .ignore();
  }

  // ── Static restore ────────────────────────────────────────────────

  static Future<ModeBNavState?> tryRestoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(kModeBNavActive) ?? false;
      if (!active) return null;

      final routeJson = prefs.getString(kModeBNavRouteJson);
      if (routeJson == null) return null;

      final route = TouristRouteEntity.fromJson(
          jsonDecode(routeJson) as Map<String, dynamic>);
      final wpIdx = prefs.getInt(kModeBNavWaypointIdx) ?? 0;
      final foodKcal = prefs.getInt(kModeBNavFoodKcal) ?? 0;
      final foodName = prefs.getString(kModeBNavFoodName) ?? '';
      final elapsedKcal = prefs.getDouble(kModeBNavElapsedKcal) ?? 0.0;

      // GPX 포인트는 복원하지 않음 — 맵 화면 진입 시 gpxpath로 재로드함
      return ModeBNavState(
        isNavigating: true,
        route: route,
        currentWaypointIdx: wpIdx,
        gpxPoints: const [],
        foodKcal: foodKcal,
        foodName: foodName,
        elapsedKcal: elapsedKcal,
        nextInstruction: '안내를 재개합니다',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  int _calcTotalDistanceM(
    TouristRouteEntity route,
    List<({double lat, double lng})> gpxPoints,
    List<double> segmentDistancesM,
  ) {
    if (route.isGenerated && segmentDistancesM.isNotEmpty) {
      return segmentDistancesM.fold(0.0, (a, b) => a + b).round();
    }
    if (route.isGenerated && route.waypoints.isNotEmpty) {
      double d = 0;
      double prevLat = route.startLat ?? 0;
      double prevLng = route.startLng ?? 0;
      for (final wp in route.waypoints) {
        d += _dist(prevLat, prevLng, wp.lat, wp.lng);
        prevLat = wp.lat;
        prevLng = wp.lng;
      }
      return d.round();
    }
    if (gpxPoints.isNotEmpty) {
      double d = 0;
      for (int i = 0; i < gpxPoints.length - 1; i++) {
        d += _dist(gpxPoints[i].lat, gpxPoints[i].lng,
            gpxPoints[i + 1].lat, gpxPoints[i + 1].lng);
      }
      return d.round();
    }
    return (route.distanceKm * 1000).round();
  }

  String _buildFirstInstruction(TouristRouteEntity route) {
    if (route.isGenerated && route.waypoints.isNotEmpty) {
      return '${route.waypoints.first.name}으로 이동하세요';
    }
    if (route.hasCoordinate) return '코스 시작점으로 이동 후 경로를 따라가세요';
    return '경로를 따라 이동하세요';
  }

  /// 실시간 GPS 틱마다 호출되므로 [fastDistanceM](Equirectangular 근사)을 사용한다.
  double _dist(double lat1, double lng1, double lat2, double lng2) =>
      fastDistanceM(lat1, lng1, lat2, lng2);
}
