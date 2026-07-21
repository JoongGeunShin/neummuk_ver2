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
/// [landmarks]는 지도 확인용 이름표(wpt)일 뿐, 재생 경로에는 영향을 주지 않는다.
/// 두 목록을 하나로 합치면 트랙이 스팟으로 직선 점프했다가 되돌아오는 왜곡이 생기므로 분리해서 다룬다.
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

  for (final l in landmarks) {
    buffer
      ..writeln('  <wpt lat="${l.lat}" lon="${l.lng}">')
      ..writeln('    <name>${_esc(l.name)}</name>')
      ..writeln('  </wpt>');
  }

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
