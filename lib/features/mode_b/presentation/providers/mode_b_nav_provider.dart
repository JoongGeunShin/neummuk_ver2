import 'dart:convert';
import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) async {
    final isBike = route.type == '자전거';
    final speedMs = isBike ? 4.17 : 1.25;
    final totalM = _calcTotalDistanceM(route, gpxPoints);
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

  void onPositionUpdate(double lat, double lng, double weightKg, String transport) {
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
    final met = transport == 'bike' ? 6.0 : 3.5;
    final newKcal = dtHours < (1.0 / 60.0)
        ? state.elapsedKcal + met * weightKg * dtHours
        : state.elapsedKcal;

    if (route.isGenerated && route.waypoints.isNotEmpty) {
      _updateGeneratedNav(lat, lng, newKcal, transport, route);
    } else if (state.gpxPoints.isNotEmpty) {
      _updateGpxNav(lat, lng, newKcal, transport);
    } else {
      state = state.copyWith(elapsedKcal: newKcal);
    }

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
    final offRoute = bestDist > 80;

    state = state.copyWith(
      nearestGpxPtIdx: bestIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      nextInstruction: isNearEnd ? '코스 종점에 거의 다 왔어요!' : '경로를 따라 계속 이동하세요',
      isOffRoute: offRoute,
      elapsedKcal: newKcal,
    );
  }

  void _updateGeneratedNav(
    double lat,
    double lng,
    double newKcal,
    String transport,
    TouristRouteEntity route,
  ) {
    final wps = route.waypoints;
    var curIdx = state.currentWaypointIdx;

    if (curIdx >= wps.length) {
      state = state.copyWith(
        remainingDistanceM: 0,
        remainingSec: 0,
        nextInstruction: '모든 스팟을 방문했어요! 🎉',
        elapsedKcal: newKcal,
        isOffRoute: false,
      );
      return;
    }

    final target = wps[curIdx];
    final distToTarget = _dist(lat, lng, target.lat, target.lng);
    final isBike = transport == 'bike';
    final speedMs = isBike ? 4.17 : 1.25;

    String instruction;

    if (distToTarget < 50) {
      curIdx++;
      if (curIdx < wps.length) {
        instruction = '${target.name} 도착! ➡ ${wps[curIdx].name}으로 이동';
      } else {
        instruction = '${target.name} 도착! 코스 완료 🎉';
      }
    } else {
      final distLabel = distToTarget < 1000
          ? '${distToTarget.round()}m'
          : '${(distToTarget / 1000).toStringAsFixed(1)}km';
      instruction = '${target.name}까지 $distLabel';
    }

    double remM = curIdx < wps.length
        ? _dist(lat, lng, wps[curIdx].lat, wps[curIdx].lng)
        : 0;
    for (int i = curIdx; i < wps.length - 1; i++) {
      remM += _dist(wps[i].lat, wps[i].lng, wps[i + 1].lat, wps[i + 1].lng);
    }

    state = state.copyWith(
      currentWaypointIdx: curIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      nextInstruction: instruction,
      isOffRoute: false,
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
  ) {
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

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0, toRad = math.pi / 180;
    final dLat = (lat2 - lat1) * toRad;
    final dLng = (lng2 - lng1) * toRad;
    final cosLat = math.cos(lat1 * toRad);
    return r * math.sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }
}
