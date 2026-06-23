import 'dart:math' as math;

import '../../../../core/constants/app_constants.dart';
import '../entities/spot_entity.dart';
import '../entities/tourist_route_entity.dart';

/// 스팟 목록 → 칼로리 목표에 맞는 원점 회귀 코스 생성
class ModeBCourseGenerator {
  const ModeBCourseGenerator();

  /// [spots]          : 후보 스팟 풀 (자동 선택 대상)
  /// [mandatorySpots] : 반드시 포함할 스팟 (카트 기반) — TSP 최적 순서로 먼저 배치
  /// [forceAll]       : true = spots 전부 포함 (mandatorySpots 없을 때 카트 전체 전달용)
  /// [maxWaypoints]   : 자동 선택 시 최대 경유지 수
  TouristRouteEntity? generate({
    required List<SpotEntity> spots,
    required double userLat,
    required double userLng,
    required int targetKcal,
    required String transport,
    required double weightKg,
    List<SpotEntity> mandatorySpots = const [],
    bool forceAll = false,
    int maxWaypoints = 5,
  }) {
    if (spots.isEmpty && mandatorySpots.isEmpty) return null;

    final isBike = transport == 'bike';
    final met = isBike ? AppConstants.metValues['bike']! : AppConstants.metValues['walk']!;
    final speedKmh = isBike ? 15.0 : 4.0;
    // 직선거리 → 도로 실거리 보정 계수 (도심 보행 1.3, 자전거 1.25)
    final routeFactor = isBike ? 1.25 : 1.3;

    final targetHours = targetKcal / (met * weightKg);
    final targetKmRoad = targetHours * speedKmh;
    // 선택 알고리즘은 직선거리 기반이므로 목표를 역보정해서 전달
    final targetKm = targetKmRoad / routeFactor;
    final tolerance = AppConstants.kcalMatchTolerancePct;
    final maxKm = targetKm * (1 + tolerance);

    List<SpotEntity> selected;

    if (forceAll) {
      // spots 전체 포함 + TSP 순서 (카트 전체를 spots로 전달하는 단순 케이스)
      selected = _tspOrder(spots, userLat, userLng);
    } else if (mandatorySpots.isNotEmpty) {
      // 필수 스팟 먼저 (TSP), 그 다음 spots 풀에서 자동 보충
      selected = _selectWithMandatory(
        mandatory: mandatorySpots,
        optional: spots,
        userLat: userLat,
        userLng: userLng,
        targetKm: targetKm,
        maxKm: maxKm,
        tolerance: tolerance,
        maxWaypoints: maxWaypoints,
      );
    } else {
      // 순수 자동 선택
      selected = _selectAuto(
        spots: spots,
        fromLat: userLat,
        fromLng: userLng,
        userLat: userLat,
        userLng: userLng,
        accumulated: 0.0,
        targetKm: targetKm,
        maxKm: maxKm,
        tolerance: tolerance,
        maxWaypoints: maxWaypoints,
      );
    }

    if (selected.isEmpty) return null;

    // 귀환 포함 총 직선 거리 계산
    double straightKm = 0.0;
    double curLat = userLat, curLng = userLng;
    for (final s in selected) {
      straightKm += _distKm(curLat, curLng, s.lat, s.lng);
      curLat = s.lat;
      curLng = s.lng;
    }
    straightKm += _distKm(curLat, curLng, userLat, userLng);

    // 직선거리 → 도로 실거리 보정
    final actualDistKm = straightKm * routeFactor;
    final actualHours = actualDistKm / speedKmh;
    final actualKcal = (met * weightKg * actualHours).round();
    final actualMinutes = (actualHours * 60).round().clamp(1, 9999);

    final waypoints = [
      ...selected.map((s) => SpotWaypoint(name: s.name, lat: s.lat, lng: s.lng, type: s.type)),
      SpotWaypoint(name: '출발지', lat: userLat, lng: userLng, type: '출발지'),
    ];

    final routeName = selected.length == 1
        ? '${selected.first.name} 코스'
        : '${selected.first.name} → ${selected.last.name} 코스';

    return TouristRouteEntity(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      name: routeName,
      distanceKm: double.parse(actualDistKm.toStringAsFixed(2)),
      durationMinutes: actualMinutes,
      kcal: actualKcal,
      type: isBike ? '자전거' : '도보',
      tags: ['🗺️ 생성됨', if (selected.length > 1) '${selected.length}개 스팟'],
      startLat: userLat,
      startLng: userLng,
      endLat: userLat,
      endLng: userLng,
      waypoints: waypoints,
      isGenerated: true,
      source: 'generated',
    );
  }

  // ── 필수 스팟 우선 + 자동 보충 ───────────────────────────────────

  List<SpotEntity> _selectWithMandatory({
    required List<SpotEntity> mandatory,
    required List<SpotEntity> optional,
    required double userLat,
    required double userLng,
    required double targetKm,
    required double maxKm,
    required double tolerance,
    required int maxWaypoints,
  }) {
    // 1) 필수 스팟: TSP 최적 순서
    final ordered = _tspOrder(mandatory, userLat, userLng);

    // 2) 필수 스팟 이후 누적 거리 + 현재 위치 계산
    double accumulated = 0.0;
    double curLat = userLat, curLng = userLng;
    for (final s in ordered) {
      accumulated += _distKm(curLat, curLng, s.lat, s.lng);
      curLat = s.lat;
      curLng = s.lng;
    }
    final returnDist = _distKm(curLat, curLng, userLat, userLng);

    // 3) 필수만으로 목표 이미 달성 or 추가 슬롯 없으면 종료
    final slotsLeft = maxWaypoints - ordered.length;
    if (accumulated + returnDist >= targetKm * (1 - tolerance) ||
        slotsLeft <= 0 ||
        optional.isEmpty) {
      return ordered;
    }

    // 4) 필수 스팟 ID 제외한 optional 풀에서 자동 보충
    final mandatoryIds = mandatory.map((s) => s.id).toSet();
    final pool = optional.where((s) => !mandatoryIds.contains(s.id)).toList();

    final extras = _selectAuto(
      spots: pool,
      fromLat: curLat,      // 마지막 필수 스팟에서 이어서 탐색
      fromLng: curLng,
      userLat: userLat,
      userLng: userLng,
      accumulated: accumulated,
      targetKm: targetKm,
      maxKm: maxKm,
      tolerance: tolerance,
      maxWaypoints: slotsLeft,
    );

    return [...ordered, ...extras];
  }

  // ── 자동 선택 (greedy NN, 임의 시작점 지원) ───────────────────────

  List<SpotEntity> _selectAuto({
    required List<SpotEntity> spots,
    required double fromLat,     // 탐색 시작 위치
    required double fromLng,
    required double userLat,     // 출발지 (귀환 거리 계산용)
    required double userLng,
    required double accumulated, // 이미 누적된 거리
    required double targetKm,
    required double maxKm,
    required double tolerance,
    required int maxWaypoints,
  }) {
    // 필터: 출발지에서 왕복 최소 거리 기준 (spot까지 직선 * 2 ≤ maxKm)
    final candidates = spots
        .map((s) => (spot: s, d: _distKm(userLat, userLng, s.lat, s.lng)))
        .where((e) => e.d > 0 && e.d <= maxKm / 2)
        .toList()
      ..sort((a, b) => a.d.compareTo(b.d));

    if (candidates.isEmpty) return [];

    final remaining = List.of(candidates);
    final selected = <SpotEntity>[];
    double curLat = fromLat;
    double curLng = fromLng;
    double acc = accumulated;

    while (remaining.isNotEmpty && selected.length < maxWaypoints) {
      int nearestIdx = 0;
      double nearestDist = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = _distKm(curLat, curLng, remaining[i].spot.lat, remaining[i].spot.lng);
        if (d < nearestDist) {
          nearestDist = d;
          nearestIdx = i;
        }
      }

      final pick = remaining[nearestIdx];
      final newTotal = acc + nearestDist;
      final returnDist = _distKm(pick.spot.lat, pick.spot.lng, userLat, userLng);

      if (newTotal + returnDist > maxKm && selected.isNotEmpty) break;

      remaining.removeAt(nearestIdx);
      selected.add(pick.spot);
      acc = newTotal;
      curLat = pick.spot.lat;
      curLng = pick.spot.lng;

      final totalWithReturn = acc + _distKm(curLat, curLng, userLat, userLng);
      if (totalWithReturn >= targetKm * (1 - tolerance)) break;
    }

    return selected;
  }

  // ── TSP ──────────────────────────────────────────────────────────

  /// N ≤ 8: 완전 탐색, N > 8: 최근접 이웃 그리디
  List<SpotEntity> _tspOrder(List<SpotEntity> spots, double startLat, double startLng) {
    if (spots.length <= 1) return List.of(spots);
    if (spots.length <= 8) return _tspBruteForce(spots, startLat, startLng);
    return _tspGreedyNN(spots, startLat, startLng);
  }

  List<SpotEntity> _tspBruteForce(
      List<SpotEntity> spots, double startLat, double startLng) {
    final indices = List.generate(spots.length, (i) => i);
    List<int> bestPerm = List.of(indices);
    double bestDist = double.infinity;

    void permute(List<int> arr, int k) {
      if (k == arr.length) {
        double dist =
            _distKm(startLat, startLng, spots[arr[0]].lat, spots[arr[0]].lng);
        for (var i = 0; i < arr.length - 1; i++) {
          dist += _distKm(spots[arr[i]].lat, spots[arr[i]].lng,
              spots[arr[i + 1]].lat, spots[arr[i + 1]].lng);
        }
        dist += _distKm(
            spots[arr.last].lat, spots[arr.last].lng, startLat, startLng);
        if (dist < bestDist) {
          bestDist = dist;
          bestPerm = List.of(arr);
        }
        return;
      }
      for (var i = k; i < arr.length; i++) {
        final tmp = arr[k];
        arr[k] = arr[i];
        arr[i] = tmp;
        permute(arr, k + 1);
        final t = arr[k];
        arr[k] = arr[i];
        arr[i] = t;
      }
    }

    permute(indices, 0);
    return bestPerm.map((i) => spots[i]).toList();
  }

  List<SpotEntity> _tspGreedyNN(
      List<SpotEntity> spots, double startLat, double startLng) {
    final remaining = List.of(spots);
    final result = <SpotEntity>[];
    double curLat = startLat, curLng = startLng;

    while (remaining.isNotEmpty) {
      int nearestIdx = 0;
      double nearestDist = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = _distKm(curLat, curLng, remaining[i].lat, remaining[i].lng);
        if (d < nearestDist) {
          nearestDist = d;
          nearestIdx = i;
        }
      }
      final pick = remaining.removeAt(nearestIdx);
      result.add(pick);
      curLat = pick.lat;
      curLng = pick.lng;
    }
    return result;
  }

  // ── 거리 계산 ─────────────────────────────────────────────────────

  double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
