import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// GPX 파일에서 파싱한 좌표 하나 (trkpt/rtept).
class GpxPoint {
  const GpxPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// 두루누비 등에서 제공하는 GPX 트랙 파일을 다운로드/파싱하는 공용 유틸.
/// mode_a(마커용 시작점)와 mode_b(내비게이션 폴리라인)가 동일한 로직을 공유한다.
class GpxUtils {
  GpxUtils._();

  static final RegExp _pattern = RegExp(
    r'<(?:trkpt|rtept)\s[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"',
  );
  static final RegExp _patternAlt = RegExp(
    r'<(?:trkpt|rtept)\s[^>]*lon="([^"]+)"[^>]*lat="([^"]+)"',
  );

  // 코스 목록 노출 시 반복 다운로드를 피하기 위한 프로세스 수명 캐시.
  static final Map<String, GpxPoint?> _firstPointCache = {};

  static List<GpxPoint> parsePoints(String xmlBody) {
    final points = <GpxPoint>[];
    for (final m in _pattern.allMatches(xmlBody)) {
      final lat = double.tryParse(m.group(1) ?? '');
      final lng = double.tryParse(m.group(2) ?? '');
      if (lat != null && lng != null) points.add(GpxPoint(lat, lng));
    }
    if (points.isEmpty) {
      for (final m in _patternAlt.allMatches(xmlBody)) {
        final lng = double.tryParse(m.group(1) ?? '');
        final lat = double.tryParse(m.group(2) ?? '');
        if (lat != null && lng != null) points.add(GpxPoint(lat, lng));
      }
    }
    return points;
  }

  /// 전체 트랙 좌표 (내비게이션 폴리라인용). [sampleLimit] 초과 시 등간격 샘플링.
  static Future<List<GpxPoint>> fetchPoints(
    String url, {
    int? sampleLimit,
  }) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final points = parsePoints(res.body);
      if (sampleLimit != null && points.length > sampleLimit) {
        final step = points.length ~/ sampleLimit;
        return [for (int i = 0; i < points.length; i += step) points[i]];
      }
      return points;
    } catch (e) {
      debugPrint('[GPX] fetchPoints error: $e url=$url');
      return [];
    }
  }

  /// 코스 시작점만 (마커 표시용). 같은 URL은 프로세스 내에서 1회만 다운로드한다.
  static Future<GpxPoint?> fetchFirstPoint(String url) async {
    if (_firstPointCache.containsKey(url)) return _firstPointCache[url];
    final points = await fetchPoints(url);
    final first = points.isNotEmpty ? points.first : null;
    _firstPointCache[url] = first;
    return first;
  }
}
