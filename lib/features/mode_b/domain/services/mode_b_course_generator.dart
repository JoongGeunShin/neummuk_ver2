import 'dart:math' as math;

import '../../../../core/constants/app_constants.dart';
import '../entities/spot_entity.dart';
import '../entities/tourist_route_entity.dart';

/// 스팟 목록 → 칼로리 목표에 맞는 코스 생성 (Nearest Neighbor greedy)
class ModeBCourseGenerator {
  const ModeBCourseGenerator();

  /// [spots]: 반경 내 스팟 목록
  /// [userLat]/[userLng]: 사용자 현재 위치 (코스 시작점)
  /// [targetKcal]: 소모 목표 칼로리 (선택한 음식의 kcal)
  /// [transport]: 'walk' | 'bike'
  /// [weightKg]: 사용자 체중
  ///
  /// 반환: 생성된 코스 또는 null (스팟 없음 / 목표 달성 불가)
  TouristRouteEntity? generate({
    required List<SpotEntity> spots,
    required double userLat,
    required double userLng,
    required int targetKcal,
    required String transport,
    required double weightKg,
  }) {
    if (spots.isEmpty) return null;

    final isBike = transport == 'bike';
    final met = isBike ? AppConstants.metValues['bike']! : AppConstants.metValues['walk']!;
    final speedKmh = isBike ? 15.0 : 4.0;

    final targetHours = targetKcal / (met * weightKg);
    final targetKm = targetHours * speedKmh;
    final tolerance = AppConstants.kcalMatchTolerancePct;
    final maxKm = targetKm * (1 + tolerance);

    // 거리순 정렬된 후보 목록
    final candidates = spots
        .map((s) => (spot: s, d: _distKm(userLat, userLng, s.lat, s.lng)))
        .where((e) => e.d <= maxKm)
        .toList()
      ..sort((a, b) => a.d.compareTo(b.d));

    if (candidates.isEmpty) return null;

    // Nearest Neighbor greedy
    final remaining = List.of(candidates);
    final selected = <SpotEntity>[];
    double curLat = userLat;
    double curLng = userLng;
    double accumulated = 0.0;

    while (remaining.isNotEmpty) {
      int nearestIdx = 0;
      double nearestDist = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = _distKm(curLat, curLng, remaining[i].spot.lat, remaining[i].spot.lng);
        if (d < nearestDist) {
          nearestDist = d;
          nearestIdx = i;
        }
      }

      final newTotal = accumulated + nearestDist;
      if (newTotal > maxKm && selected.isNotEmpty) break;

      final pick = remaining.removeAt(nearestIdx);
      selected.add(pick.spot);
      accumulated = newTotal;
      curLat = pick.spot.lat;
      curLng = pick.spot.lng;

      // 목표 범위 내 충족 → 종료
      if (accumulated >= targetKm * (1 - tolerance)) break;
    }

    if (selected.isEmpty) return null;

    final actualHours = accumulated / speedKmh;
    final actualKcal = (met * weightKg * actualHours).round();
    final actualMinutes = (actualHours * 60).round().clamp(1, 9999);

    final waypoints = selected
        .map((s) => SpotWaypoint(name: s.name, lat: s.lat, lng: s.lng, type: s.type))
        .toList();

    final routeName = selected.length == 1
        ? '${selected.first.name} 코스'
        : '${selected.first.name} → ${selected.last.name} 코스';

    return TouristRouteEntity(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      name: routeName,
      distanceKm: double.parse(accumulated.toStringAsFixed(2)),
      durationMinutes: actualMinutes,
      kcal: actualKcal,
      type: isBike ? '자전거' : '도보',
      tags: ['🗺️ 생성됨', if (selected.length > 1) '${selected.length}개 스팟'],
      startLat: userLat,
      startLng: userLng,
      endLat: selected.last.lat,
      endLng: selected.last.lng,
      waypoints: waypoints,
      isGenerated: true,
      source: 'generated',
    );
  }

  double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
