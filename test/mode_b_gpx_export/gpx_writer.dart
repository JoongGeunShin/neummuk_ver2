/// 좌표 목록을 안드로이드 스튜디오 에뮬레이터의
/// Extended Controls > Location > Routes 에서 바로 import 가능한 GPX 파일로 직렬화한다.
class GpxPoint {
  const GpxPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class GpxLandmark {
  const GpxLandmark({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;
}

/// [points]는 실제 이동 순서대로의 도로 경로(trk) — 재생될 실제 좌표 시퀀스.
/// [landmarks]는 어느 스팟이 어디인지 확인하는 용도일 뿐이라 GPX에는 쓰지 않는다 — 안드로이드
/// 스튜디오 에뮬레이터의 Routes 임포터가 `<wpt>`를 `<trk>`와 같이 읽어 스팟 사이를 직선으로
/// 잇는 것으로 보여서(재생이 아니라 import 단계에서 섞임), 순수 `<trk>`만 남기고 라벨은
/// [describeLandmarks]로 콘솔에 따로 출력한다.
String buildGpx({
  required String routeName,
  required List<GpxPoint> points,
  List<GpxLandmark> landmarks = const [],
}) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
        '<gpx version="1.1" creator="neummuk_ver2" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <metadata><name>${_esc(routeName)}</name></metadata>');

  buffer
    ..writeln('  <trk>')
    ..writeln('    <name>${_esc(routeName)}</name>')
    ..writeln('    <trkseg>');
  for (final p in points) {
    buffer.writeln('      <trkpt lat="${p.lat}" lon="${p.lng}"></trkpt>');
  }
  buffer
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');

  return buffer.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// GPX 파일에는 넣지 않는 스팟 이름표를 콘솔 확인용으로 출력한다.
String describeLandmarks(List<GpxLandmark> landmarks) => landmarks
    .map((l) => '  - ${l.name}: ${l.lat}, ${l.lng}')
    .join('\n');
