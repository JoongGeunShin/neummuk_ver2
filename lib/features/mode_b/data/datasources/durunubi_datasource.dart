import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';

class DurunubiDatasource {
  // 앱 버전 올릴 때 v숫자를 올리면 기존 캐시가 자동 무효화됨
  static const _diskCacheKey = 'durunubi_courses_v1';
  static const _diskCacheTimeKey = 'durunubi_courses_time_v1';
  static const _cacheTtl = Duration(hours: 24);
  static const _pageSize = 100;

  // 프로세스 수명 동안 유지되는 인메모리 캐시
  static List<Map<String, dynamic>>? _memCache;
  static DateTime? _memCacheTime;

  /// 전체 코스 목록 조회 (인메모리 → 디스크 → API 순으로 조회)
  Future<List<Map<String, dynamic>>> fetchAllCoursesCached() async {
    // 1. 인메모리 캐시
    if (_memCache != null && _memCacheTime != null) {
      if (DateTime.now().difference(_memCacheTime!) < _cacheTtl) {
        debugPrint('[Durunubi] memory cache hit (${_memCache!.length} courses)');
        return _memCache!;
      }
    }

    // 2. 디스크 캐시
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt(_diskCacheTimeKey) ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - savedMs;
    if (ageMs < _cacheTtl.inMilliseconds) {
      final raw = prefs.getString(_diskCacheKey);
      if (raw != null) {
        try {
          final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          _memCache = items;
          _memCacheTime = DateTime.fromMillisecondsSinceEpoch(savedMs);
          debugPrint('[Durunubi] disk cache hit (${items.length} courses)');
          return items;
        } catch (e) {
          // 파싱 실패 시 API 재요청 (스키마 변경 등)
          debugPrint('[Durunubi] disk cache parse error, refetching: $e');
        }
      }
    }

    // 3. API 페이지네이션 fetch
    final items = await _fetchAllPages();

    // 4. 캐시 저장
    _memCache = items;
    _memCacheTime = DateTime.now();
    try {
      await prefs.setString(_diskCacheKey, jsonEncode(items));
      await prefs.setInt(_diskCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[Durunubi] saved ${items.length} courses to disk cache');
    } catch (e) {
      // 캐시 저장 실패는 치명적이지 않음 — 다음 실행 시 재시도
      debugPrint('[Durunubi] disk cache write error: $e');
    }

    return items;
  }

  Future<List<Map<String, dynamic>>> _fetchAllPages() async {
    // 1페이지로 totalCount 확인
    final first = await _fetchPage(_pageSize, 1);
    final total = first.$1;
    final items = List<Map<String, dynamic>>.from(first.$2);

    if (total <= _pageSize) return items;

    final totalPages = (total / _pageSize).ceil();
    debugPrint('[Durunubi] totalCount=$total → $totalPages pages');

    // 나머지 페이지 병렬 fetch
    final futures = [
      for (int p = 2; p <= totalPages; p++) _fetchPage(_pageSize, p),
    ];

    // 일부 페이지 실패해도 나머지는 반환 (eagerError: false 기본값)
    final results = await Future.wait(futures, eagerError: false);
    for (final r in results) {
      items.addAll(r.$2);
    }

    debugPrint('[Durunubi] fetched ${items.length}/$total courses total');
    return items;
  }

  Future<(int total, List<Map<String, dynamic>> items)> _fetchPage(
    int pageSize,
    int pageNo,
  ) async {
    final key = AppEnv.dataGoKey;
    if (key.isEmpty) {
      debugPrint('[Durunubi] API key not set');
      return (0, <Map<String, dynamic>>[]);
    }

    final uri = Uri.parse('${AppConstants.durunubiBaseUrl}/courseList').replace(
      queryParameters: {
        'ServiceKey': key,
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        'numOfRows': '$pageSize',
        'pageNo': '$pageNo',
        '_type': 'json',
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      debugPrint('[Durunubi] page $pageNo → HTTP ${res.statusCode}');

      if (res.statusCode != 200) return (0, <Map<String, dynamic>>[]);
      if (res.body.trimLeft().startsWith('<')) {
        debugPrint('[Durunubi] XML error on page $pageNo: ${res.body}');
        return (0, <Map<String, dynamic>>[]);
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final resBody = body['response']?['body'];
      final total =
          int.tryParse(resBody?['totalCount']?.toString() ?? '') ?? 0;
      final raw = resBody?['items']?['item'];

      if (raw == null) return (total, <Map<String, dynamic>>[]);
      if (raw is List) return (total, raw.cast<Map<String, dynamic>>());
      if (raw is Map) return (total, [Map<String, dynamic>.from(raw)]);
      return (total, <Map<String, dynamic>>[]);
    } catch (e) {
      debugPrint('[Durunubi] page $pageNo fetch error: $e');
      return (0, <Map<String, dynamic>>[]);
    }
  }
}
