import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../domain/entities/event_entity.dart';

class TourApiEventsDatasource {
  // 행사/공연/축제 contentTypeId
  static const int _contentTypeId = 15;

  // 전국 임박 행사 in-memory cache (TTL 1h)
  List<EventEntity>? _upcomingCache;
  DateTime? _upcomingCachedAt;
  static const _cacheTtl = Duration(hours: 1);

  bool get _upcomingCacheValid =>
      _upcomingCache != null &&
      _upcomingCachedAt != null &&
      DateTime.now().difference(_upcomingCachedAt!) < _cacheTtl;

  /// searchFestival2 — 오늘 이후 행사 목록 (위치 무관, 시작일 기준 정렬)
  Future<List<EventEntity>> fetchUpcomingEvents({int numOfRows = 8}) async {
    if (_upcomingCacheValid) return _upcomingCache!;

    final key = AppEnv.dataGoKey;
    if (key.isEmpty) {
      debugPrint('[TourApiEvents] DATA_GO_KEY not set');
      return [];
    }

    final now = DateTime.now();
    // 14일 전부터 조회해 최근 종료 행사도 포함
    final from = now.subtract(const Duration(days: 14));
    final fromStr =
        '${from.year}${from.month.toString().padLeft(2, '0')}${from.day.toString().padLeft(2, '0')}';

    final uri =
        Uri.parse('${AppConstants.tourApiBaseUrl}/searchFestival2').replace(
      queryParameters: {
        'serviceKey': key,
        'numOfRows': '$numOfRows',
        'pageNo': '1',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        'eventStartDate': fromStr,
        'arrange': 'A',
        '_type': 'json',
      },
    );

    try {
      debugPrint('[TourApiEvents] upcoming $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      if (res.body.trimLeft().startsWith('<')) {
        debugPrint('[TourApiEvents] XML error');
        return [];
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final header = body['response']?['header'];
      debugPrint('[TourApiEvents] resultCode=${header?['resultCode']}');

      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) {
        debugPrint('[TourApiEvents] no upcoming events');
        return [];
      }

      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [Map<String, dynamic>.from(raw as Map)];

      final events = list
          .map((item) => _parse(item))
          .whereType<EventEntity>()
          .toList()
        ..sort(_sortByUrgency);

      debugPrint('[TourApiEvents] ${events.length} upcoming events');
      _upcomingCache = events;
      _upcomingCachedAt = DateTime.now();
      return events;
    } catch (e) {
      debugPrint('[TourApiEvents] fetchUpcomingEvents error: $e');
      return [];
    }
  }

  /// locationBasedList2 (contentTypeId=15) — 위치 반경 내 행사, 거리순
  Future<List<EventEntity>> fetchNearbyEvents({
    required double lat,
    required double lng,
    int numOfRows = 8,
    int radiusM = 20000,
  }) async {
    final key = AppEnv.dataGoKey;
    if (key.isEmpty) return [];

    final uri =
        Uri.parse('${AppConstants.tourApiBaseUrl}/locationBasedList2').replace(
      queryParameters: {
        'serviceKey': key,
        'numOfRows': '$numOfRows',
        'pageNo': '1',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        'mapX': '$lng',
        'mapY': '$lat',
        'radius': '$radiusM',
        'contentTypeId': '$_contentTypeId',
        'arrange': 'E',
        '_type': 'json',
      },
    );

    try {
      debugPrint('[TourApiEvents] nearby $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      if (res.body.trimLeft().startsWith('<')) return [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) {
        debugPrint('[TourApiEvents] no nearby events');
        return [];
      }

      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [Map<String, dynamic>.from(raw as Map)];

      final events = list
          .map((item) => _parseWithDist(item))
          .whereType<EventEntity>()
          .toList()
        ..sort(_sortByUrgency);

      debugPrint('[TourApiEvents] ${events.length} nearby events');
      return events;
    } catch (e) {
      debugPrint('[TourApiEvents] fetchNearbyEvents error: $e');
      return [];
    }
  }

  EventEntity? _parse(Map<String, dynamic> item) {
    try {
      final id = 'event_${item['contentid'] ?? ''}';
      final name = item['title']?.toString() ?? '';
      if (name.isEmpty) return null;

      return EventEntity(
        id: id,
        name: name,
        addr: item['addr1']?.toString(),
        startDate: _parseDate(item['eventstartdate']?.toString()),
        endDate: _parseDate(item['eventenddate']?.toString()),
        lat: double.tryParse(item['mapy']?.toString() ?? ''),
        lng: double.tryParse(item['mapx']?.toString() ?? ''),
        imageUrl: _pickImage(item),
      );
    } catch (e) {
      debugPrint('[TourApiEvents] parse error: $e');
      return null;
    }
  }

  EventEntity? _parseWithDist(Map<String, dynamic> item) {
    final entity = _parse(item);
    if (entity == null) return null;
    final dist =
        int.tryParse(item['dist']?.toString().split('.').first ?? '') ?? 0;
    return EventEntity(
      id: entity.id,
      name: entity.name,
      addr: entity.addr,
      startDate: entity.startDate,
      endDate: entity.endDate,
      lat: entity.lat,
      lng: entity.lng,
      imageUrl: entity.imageUrl,
      distanceFromUserM: dist > 0 ? dist : null,
    );
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.length < 8) return null;
    try {
      return DateTime(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
      );
    } catch (_) {
      return null;
    }
  }

  String? _pickImage(Map<String, dynamic> item) {
    final img1 = item['firstimage']?.toString() ?? '';
    if (img1.isNotEmpty) return img1;
    final img2 = item['firstimage2']?.toString() ?? '';
    return img2.isNotEmpty ? img2 : null;
  }

  // 진행중 → 오늘 시작 → D-N 오름차순 → 종료됨
  int _sortByUrgency(EventEntity a, EventEntity b) {
    if (a.isEnded != b.isEnded) return a.isEnded ? 1 : -1;
    if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
    final da = a.daysUntilStart ?? 9999;
    final db = b.daysUntilStart ?? 9999;
    return da.compareTo(db);
  }
}
