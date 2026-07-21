import 'dart:io';
import 'dart:math' as math;

double haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

void main(List<String> args) {
  final file = File(args[0]);
  final text = file.readAsStringSync();
  final wptPattern = RegExp(r'<wpt lat="([^"]+)" lon="([^"]+)">\s*<name>([^<]*)</name>');
  final trkptPattern = RegExp(r'<trkpt lat="([^"]+)" lon="([^"]+)">');

  final wpts = wptPattern.allMatches(text).map((m) => (
        lat: double.parse(m.group(1)!),
        lng: double.parse(m.group(2)!),
        name: m.group(3)!,
      )).toList();

  final trkpts = trkptPattern.allMatches(text).map((m) => (
        lat: double.parse(m.group(1)!),
        lng: double.parse(m.group(2)!),
      )).toList();

  print('총 wpt: ${wpts.length}, 총 trkpt: ${trkpts.length}');
  for (final w in wpts) {
    print('  wpt: ${w.name} (${w.lat}, ${w.lng})');
  }

  print('\n--- 연속 trkpt 간 거리(m) 중 30m 넘는 구간 (직선 급점프 의심) ---');
  for (var i = 1; i < trkpts.length; i++) {
    final d = haversineM(trkpts[i - 1].lat, trkpts[i - 1].lng, trkpts[i].lat, trkpts[i].lng);
    if (d > 30) {
      print('  [$i] ${trkpts[i - 1]} -> ${trkpts[i]} : ${d.toStringAsFixed(1)}m');
    }
  }

  print('\n--- 각 wpt에 가장 가까운 trkpt까지의 거리 (해당 스팟을 trk가 실제로 지나가는지) ---');
  for (final w in wpts) {
    var best = double.infinity;
    for (final t in trkpts) {
      final d = haversineM(w.lat, w.lng, t.lat, t.lng);
      if (d < best) best = d;
    }
    print('  ${w.name}: 최근접 trkpt까지 ${best.toStringAsFixed(1)}m');
  }

  print('\n--- 전체 이동거리 합 ---');
  double total = 0;
  for (var i = 1; i < trkpts.length; i++) {
    total += haversineM(trkpts[i - 1].lat, trkpts[i - 1].lng, trkpts[i].lat, trkpts[i].lng);
  }
  print('  ${(total / 1000).toStringAsFixed(2)} km (trkpt 기준)');
}
