import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/route_result_entity.dart';

part 'mode_a_nav_provider.g.dart';

class ModeANavState {
  const ModeANavState({
    this.isNavigating = false,
    this.nearestPtIdx = 0,
    this.remainingDistanceM = 0,
    this.remainingSec = 0,
    this.nextGuide,
    this.isOffRoute = false,
    this.showReroutePrompt = false,
  });

  final bool isNavigating;
  final int nearestPtIdx;
  final int remainingDistanceM;
  final int remainingSec;
  final RouteGuide? nextGuide;
  final bool isOffRoute;
  final bool showReroutePrompt;

  String get remainingLabel => remainingDistanceM < 1000
      ? '${remainingDistanceM}m'
      : '${(remainingDistanceM / 1000).toStringAsFixed(1)}km';

  int get remainingMinutes => max(1, (remainingSec / 60).ceil());

  ModeANavState copyWith({
    bool? isNavigating,
    int? nearestPtIdx,
    int? remainingDistanceM,
    int? remainingSec,
    Object? nextGuide = _kKeep,
    bool? isOffRoute,
    bool? showReroutePrompt,
  }) {
    return ModeANavState(
      isNavigating: isNavigating ?? this.isNavigating,
      nearestPtIdx: nearestPtIdx ?? this.nearestPtIdx,
      remainingDistanceM: remainingDistanceM ?? this.remainingDistanceM,
      remainingSec: remainingSec ?? this.remainingSec,
      nextGuide: identical(nextGuide, _kKeep) ? this.nextGuide : nextGuide as RouteGuide?,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      showReroutePrompt: showReroutePrompt ?? this.showReroutePrompt,
    );
  }
}

const _kKeep = Object();

@riverpod
class ModeANav extends _$ModeANav {
  @override
  ModeANavState build() => const ModeANavState();

  void start(RouteResultEntity route) {
    final pts = route.routePoints;
    if (pts.isEmpty) return;
    double totalM = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      totalM += _dist(
          pts[i].latitude, pts[i].longitude,
          pts[i + 1].latitude, pts[i + 1].longitude);
    }
    final speedMs = route.transport == 'bike' ? 4.17 : 1.25;
    state = ModeANavState(
      isNavigating: true,
      remainingDistanceM: totalM.round(),
      remainingSec: (totalM / speedMs).round(),
      nextGuide: route.guides.isNotEmpty ? route.guides.first : null,
    );
  }

  void stop() => state = const ModeANavState();

  void dismissReroute() =>
      state = state.copyWith(showReroutePrompt: false);

  void onPositionUpdate(double lat, double lng, RouteResultEntity route) {
    if (!state.isNavigating) return;
    final pts = route.routePoints;
    if (pts.isEmpty) return;

    final start = state.nearestPtIdx;
    final end = min(pts.length, start + 150);
    int bestIdx = start;
    double bestDist = double.infinity;
    for (int i = start; i < end; i++) {
      final d = _dist(lat, lng, pts[i].latitude, pts[i].longitude);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    final offRoute = bestDist > 60;
    double remM = 0;
    for (int i = bestIdx; i < pts.length - 1; i++) {
      remM += _dist(pts[i].latitude, pts[i].longitude,
          pts[i + 1].latitude, pts[i + 1].longitude);
    }
    final speedMs = route.transport == 'bike' ? 4.17 : 1.25;

    final nextGuide = _nextGuide(bestIdx, pts, route.guides);

    state = state.copyWith(
      nearestPtIdx: bestIdx,
      remainingDistanceM: remM.round(),
      remainingSec: (remM / speedMs).round(),
      nextGuide: nextGuide,
      isOffRoute: offRoute,
      showReroutePrompt: offRoute && !state.isOffRoute,
    );
  }

  RouteGuide? _nextGuide(
      int nearestIdx, List<LatLng> pts, List<RouteGuide> guides) {
    if (guides.isEmpty) return null;
    for (final g in guides) {
      if (g.isArrival) continue;
      int guideIdx = 0;
      double minD = double.infinity;
      for (int i = 0; i < pts.length; i++) {
        final d = _dist(g.latitude, g.longitude, pts[i].latitude, pts[i].longitude);
        if (d < minD) {
          minD = d;
          guideIdx = i;
        }
      }
      if (guideIdx > nearestIdx) return g;
    }
    return guides.last; // arrival
  }

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0, toRad = pi / 180;
    final dLat = (lat2 - lat1) * toRad;
    final dLng = (lng2 - lng1) * toRad;
    final cosLat = cos(lat1 * toRad);
    return r * sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }
}
