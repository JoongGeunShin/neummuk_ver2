import 'dart:math' as math;

import 'geo_utils.dart';

/// 방향 안내 타입 — Mode A/B 내비게이션 지도 마커·카드 공용.
enum TurnType { straight, right, left, uTurn, arrival }

/// 경로(구간) 위의 턴 지점 하나.
class TurnPoint {
  const TurnPoint({
    required this.type,
    required this.ptIdx,
    required this.lat,
    required this.lng,
    required this.instruction,
    this.legIdx = 0,
  });

  final TurnType type;
  /// 소속 구간(leg) 내에서의 포인트 인덱스. 구간 구분이 없는 단일 트랙은 항상 legIdx=0.
  final int ptIdx;
  final double lat;
  final double lng;
  final String instruction;
  /// 구간(leg) 인덱스 — 단일 트랙 코스는 항상 0.
  final int legIdx;
}

/// 턴 마커의 지도 오버레이 ID — 구간+구간 내 인덱스로 결정되는 내용 기반 ID라서
/// 리스트 순서가 바뀌어도(지나간 턴 제거 등) 항상 같은 턴을 가리킨다.
String turnMarkerId(TurnPoint t) => 'turn_${t.legIdx}_${t.ptIdx}';

double bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  const toRad = math.pi / 180;
  final dLng = (lng2 - lng1) * toRad;
  final y = math.sin(dLng) * math.cos(lat2 * toRad);
  final x = math.cos(lat1 * toRad) * math.sin(lat2 * toRad) -
      math.sin(lat1 * toRad) * math.cos(lat2 * toRad) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// 경로 위 좌우회전/유턴 지점을 기하학적으로 감지한다 (Kakao guides 유무와 무관).
/// 25m 윈도우로 접근/이탈 방향을 비교해 25° 이상 꺾이면 턴으로, 120° 이상이면
/// 유턴으로 분류하고, 40m 이내에 연속으로 감지되지 않도록 최소 간격을 둔다.
/// 마지막에 항상 도착(arrival) 포인트를 하나 추가한다.
List<TurnPoint> computeTurnPoints(
  List<({double lat, double lng})> pts, {
  int legIdx = 0,
}) {
  if (pts.length < 6) return [];

  final cumDist = List<double>.filled(pts.length, 0.0);
  for (int i = 1; i < pts.length; i++) {
    cumDist[i] = cumDist[i - 1] +
        fastDistanceM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
  }

  final totalDist = cumDist.last;
  if (totalDist < 50) return [];

  const segLen = 25.0;
  const turnThreshold = 25.0;
  const uTurnThreshold = 120.0;
  const minDistSpacing = 40.0;

  final turns = <TurnPoint>[];
  double lastTurnDist = -minDistSpacing;

  for (int i = 0; i < pts.length; i++) {
    final d = cumDist[i];
    if (d < segLen || d > totalDist - segLen) continue;

    int iA = i;
    while (iA > 0 && cumDist[iA] > d - segLen) {
      iA--;
    }
    int iL = i;
    while (iL < pts.length - 1 && cumDist[iL] < d + segLen) {
      iL++;
    }

    if (iA == i || iL == i) continue;

    final approachBearing =
        bearingDeg(pts[iA].lat, pts[iA].lng, pts[i].lat, pts[i].lng);
    final leaveBearing =
        bearingDeg(pts[i].lat, pts[i].lng, pts[iL].lat, pts[iL].lng);

    double delta = leaveBearing - approachBearing;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    final absD = delta.abs();

    if (absD > turnThreshold && d - lastTurnDist >= minDistSpacing) {
      final type = absD >= uTurnThreshold
          ? TurnType.uTurn
          : delta > 0
              ? TurnType.right
              : TurnType.left;
      final instruction = absD >= uTurnThreshold
          ? '유턴하세요'
          : delta > 0
              ? '오른쪽 길로 계속 진행'
              : '왼쪽 길로 계속 진행';

      turns.add(TurnPoint(
        type: type,
        ptIdx: i,
        lat: pts[i].lat,
        lng: pts[i].lng,
        instruction: instruction,
        legIdx: legIdx,
      ));
      lastTurnDist = d;
    }
  }

  turns.add(TurnPoint(
    type: TurnType.arrival,
    ptIdx: pts.length - 1,
    lat: pts.last.lat,
    lng: pts.last.lng,
    instruction: '목적지에 도착합니다',
    legIdx: legIdx,
  ));

  return turns;
}

/// 사용자가 지나온 턴들을 걸러낸다. [currentLegIdx] 이전 구간은 전부 지난 것으로,
/// 같은 구간이면 [currentPtIdx] 이하만 지난 것으로 판단한다. 구간이 막 바뀐 틱에는
/// 호출측이 currentPtIdx로 -1을 넘겨 "이 구간의 부분 통과분" 오판정을 막는다.
List<TurnPoint> prunePassedTurnPoints(
  List<TurnPoint> turns, {
  required int currentLegIdx,
  required int currentPtIdx,
}) {
  return turns.where((t) {
    final passed = t.legIdx < currentLegIdx ||
        (t.legIdx == currentLegIdx && currentPtIdx >= 0 && t.ptIdx <= currentPtIdx);
    return !passed;
  }).toList();
}
