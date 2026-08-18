import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/event_entity.dart';
import 'event_api_shared.dart';

class TourApiEventsDatasource {
  // 전국 임박 행사 in-memory cache (TTL 1h) — 항상 최대치로 채워두고
  // 호출부(전국 탭 / 내 주변 반경 보정)는 여기서 필요한 만큼만 잘라 쓴다.
  List<EventEntity>? _upcomingCache;
  DateTime? _upcomingCachedAt;
  static const _cacheTtl = Duration(hours: 1);
  static const _upcomingRawRows = 100;

  bool get _upcomingCacheValid =>
      _upcomingCache != null &&
      _upcomingCachedAt != null &&
      DateTime.now().difference(_upcomingCachedAt!) < _cacheTtl;

  /// searchFestival2 — 오늘 이후 행사 목록 (위치 무관, 시작일 기준 정렬)
  Future<List<EventEntity>> fetchUpcomingEvents({int numOfRows = 8}) async {
    final all = await _fetchUpcomingRaw();
    return all.take(numOfRows).toList();
  }

  Future<List<EventEntity>> _fetchUpcomingRaw() async {
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
        'numOfRows': '$_upcomingRawRows',
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
          .where((e) => !e.isEnded)
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
    int numOfRows = 30,
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
        'contentTypeId': '${EventApiConstants.contentTypeId}',
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

      // locationBasedList2는 eventstartdate/eventenddate를 주지 않으므로
      // 전국 리스트(searchFestival2)와 동일한 기간/진행상태를 보여주기 위해
      // detailIntro2로 개별 보강한다.
      final enriched = await Future.wait(list.map((item) async {
        if (item['eventstartdate'] != null) return item;
        final contentId = item['contentid']?.toString() ?? '';
        final dates = await _fetchEventDates(contentId);
        if (dates != null) {
          item['eventstartdate'] = dates.start;
          item['eventenddate'] = dates.end;
        }
        return item;
      }));

      final events = enriched
          .map((item) => _parse(item))
          .whereType<EventEntity>()
          .where((e) => !e.isEnded)
          .toList();

      final merged = await _mergeNationwideFallback(events, lat, lng, radiusM);
      merged.sort(_sortByUrgency);

      debugPrint('[TourApiEvents] ${merged.length} nearby events');
      return merged;
    } catch (e) {
      debugPrint('[TourApiEvents] fetchNearbyEvents error: $e');
      return [];
    }
  }

  /// locationBasedList2는 geo-index 누락으로 실제 반경 내에 있는 행사를
  /// 종종 빠뜨린다(예: 좌표가 정상인데도 위치 검색 결과에 없는 경우).
  /// 전국 목록(searchFestival2)에서 반경 내 후보를 찾아 빠진 것만 보충한다.
  Future<List<EventEntity>> _mergeNationwideFallback(
    List<EventEntity> locationBased,
    double lat,
    double lng,
    int radiusM,
  ) async {
    final byId = {for (final e in locationBased) e.id: e};
    final nationwide = await _fetchUpcomingRaw();
    for (final e in nationwide) {
      if (byId.containsKey(e.id)) continue;
      if (e.lat == null || e.lng == null) continue;
      if (haversineDistanceM(lat, lng, e.lat!, e.lng!) > radiusM) continue;
      byId[e.id] = e;
    }
    return byId.values.toList();
  }

  /// detailIntro2 — locationBasedList2에 없는 행사 기간 보강용.
  Future<({String? start, String? end})?> _fetchEventDates(
      String contentId) async {
    if (contentId.isEmpty) return null;
    final key = AppEnv.dataGoKey;
    if (key.isEmpty) return null;

    final uri =
        Uri.parse('${AppConstants.tourApiBaseUrl}/detailIntro2').replace(
      queryParameters: {
        'serviceKey': key,
        'contentId': contentId,
        'contentTypeId': '${EventApiConstants.contentTypeId}',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        '_type': 'json',
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) return null;

      final item = raw is List
          ? (raw.isNotEmpty ? raw.first as Map<String, dynamic> : null)
          : Map<String, dynamic>.from(raw as Map);
      if (item == null) return null;

      return (
        start: item['eventstartdate']?.toString(),
        end: item['eventenddate']?.toString(),
      );
    } catch (e) {
      debugPrint('[TourApiEvents] fetchEventDates error: $e');
      return null;
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
        startDate: parseTourApiDate(item['eventstartdate']?.toString()),
        endDate: parseTourApiDate(item['eventenddate']?.toString()),
        lat: double.tryParse(item['mapy']?.toString() ?? ''),
        lng: double.tryParse(item['mapx']?.toString() ?? ''),
        imageUrl: _pickImage(item),
      );
    } catch (e) {
      debugPrint('[TourApiEvents] parse error: $e');
      return null;
    }
  }

  String? _pickImage(Map<String, dynamic> item) {
    final img1 = item['firstimage']?.toString() ?? '';
    if (img1.isNotEmpty) return img1;
    final img2 = item['firstimage2']?.toString() ?? '';
    return img2.isNotEmpty ? img2 : null;
  }

  // 진행중 → 오늘 시작 → D-N 오름차순
  int _sortByUrgency(EventEntity a, EventEntity b) {
    if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
    final da = a.daysUntilStart ?? 9999;
    final db = b.daysUntilStart ?? 9999;
    return da.compareTo(db);
  }
}
