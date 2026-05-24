import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/repositories/place_repository.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  String get _tourKey => dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';
  String get _kakaoKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  // 좌표는 외부 검색 API 파라미터로만 사용 — Firestore 저장 없음 (LAW_RESTRICT)
  @override
  Future<List<PlaceEntity>> searchNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
    String? keyword,
    bool isCategory = false,
  }) async {
    final results = await Future.wait([
      _fetchTourApi(latitude, longitude, radiusMeters, keyword, isCategory).catchError((_) => <PlaceEntity>[]),
      _fetchKakaoLocal(latitude, longitude, radiusMeters, keyword).catchError((_) => <PlaceEntity>[]),
    ]);
    return _merge(results[0], results[1], keyword);
  }

  Future<List<PlaceEntity>> _fetchTourApi(
    double lat,
    double lng,
    int radius,
    String? keyword,
    bool isCategory,
  ) async {
    final String path;
    final Map<String, String> params;

    // 카테고리 태그 선택 시: TourAPI는 위치 기반 검색 유지 (키워드로 식당명 검색 시 결과 없음)
    // 자유 텍스트 검색 시에만 searchKeyword2 사용
    if (keyword != null && keyword.isNotEmpty && !isCategory) {
      path = 'searchKeyword2';
      params = {
        'numOfRows': '30',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'neummuk',
        '_type': 'json',
        'contentTypeId': '39',
        'keyword': keyword,
        'mapX': lng.toStringAsFixed(7),
        'mapY': lat.toStringAsFixed(7),
        'radius': radius.clamp(0, 20000).toString(),
        'arrange': 'A',
      };
    } else {
      path = 'locationBasedList2';
      params = {
        'numOfRows': '30',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'neummuk',
        '_type': 'json',
        'contentTypeId': '39',
        'mapX': lng.toStringAsFixed(7),
        'mapY': lat.toStringAsFixed(7),
        'radius': radius.toString(),
        'arrange': 'S',
      };
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '${AppConstants.tourApiBaseUrl}/$path?serviceKey=$_tourKey&$queryString';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final body = json['response']?['body'];
    if (body == null) return [];

    final totalCount = int.tryParse(body['totalCount'].toString()) ?? 0;
    if (totalCount == 0) return [];

    final rawItem = body['items']?['item'];
    if (rawItem == null) return [];

    final itemList = rawItem is List ? rawItem : [rawItem];

    return itemList.map<PlaceEntity?>((item) {
      final mapx = double.tryParse(item['mapx']?.toString() ?? '');
      final mapy = double.tryParse(item['mapy']?.toString() ?? '');
      if (mapx == null || mapy == null || mapx == 0 || mapy == 0) return null;
      final name = (item['title'] as String? ?? '').trim();
      if (name.isEmpty) return null;
      return PlaceEntity(
        id: 'tour_${item['contentid']}',
        name: name,
        latitude: mapy,
        longitude: mapx,
        address: item['addr1'] as String?,
        phone: item['tel'] as String?,
        imageUrl: item['firstimage'] as String?,
        category: item['cat3'] as String?,
        source: PlaceSource.tourApi,
      );
    }).whereType<PlaceEntity>().toList();
  }

  Future<List<PlaceEntity>> _fetchKakaoLocal(
    double lat,
    double lng,
    int radius,
    String? keyword,
  ) async {
    final String path;
    final Map<String, String> params;

    if (keyword != null && keyword.isNotEmpty) {
      path = '/search/keyword.json';
      params = {
        'query': keyword,
        'x': lng.toString(),
        'y': lat.toString(),
        'radius': radius.toString(),
        'size': '15',
        'category_group_code': 'FD6',
      };
    } else {
      path = '/search/category.json';
      params = {
        'category_group_code': 'FD6',
        'x': lng.toString(),
        'y': lat.toString(),
        'radius': radius.toString(),
        'size': '15',
      };
    }

    final response = await http.get(
      Uri.parse('${AppConstants.kakaoLocalBaseUrl}$path').replace(queryParameters: params),
      headers: {'Authorization': 'KakaoAK $_kakaoKey'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = json['documents'] as List<dynamic>? ?? [];

    return documents.map<PlaceEntity?>((doc) {
      final x = double.tryParse(doc['x']?.toString() ?? '');
      final y = double.tryParse(doc['y']?.toString() ?? '');
      if (x == null || y == null || x == 0 || y == 0) return null;
      final name = (doc['place_name'] as String? ?? '').trim();
      if (name.isEmpty) return null;
      final roadAddr = doc['road_address_name'] as String? ?? '';
      return PlaceEntity(
        id: 'kakao_${doc['id']}',
        name: name,
        latitude: y,
        longitude: x,
        address: roadAddr.isNotEmpty ? roadAddr : doc['address_name'] as String?,
        phone: doc['phone'] as String?,
        category: doc['category_name'] as String?,
        source: PlaceSource.kakaoLocal,
      );
    }).whereType<PlaceEntity>().toList();
  }

  List<PlaceEntity> _merge(
    List<PlaceEntity> tour,
    List<PlaceEntity> kakao,
    String? keyword,
  ) {
    final result = List<PlaceEntity>.from(tour);

    for (final kPlace in kakao) {
      final matchIdx = result.indexWhere((t) =>
          _distM(t.latitude, t.longitude, kPlace.latitude, kPlace.longitude) < 150 &&
          _similarName(t.name, kPlace.name));

      if (matchIdx >= 0) {
        final t = result[matchIdx];
        result[matchIdx] = PlaceEntity(
          id: t.id,
          name: t.name,
          latitude: t.latitude,
          longitude: t.longitude,
          address: t.address ?? kPlace.address,
          phone: t.phone ?? kPlace.phone,
          imageUrl: t.imageUrl,
          category: t.category ?? kPlace.category,
          source: PlaceSource.both,
        );
      } else {
        result.add(kPlace);
      }
    }

    if (keyword != null && keyword.isNotEmpty) {
      final kw = keyword.toLowerCase();
      final extraKeywords = _catMap[keyword] ?? [];
      return result.where((p) {
        // TourAPI는 서버에서 이미 키워드로 필터링됨 — 클라이언트 재필터 불필요
        if (p.source != PlaceSource.kakaoLocal) return true;
        final text = '${p.name} ${p.category ?? ''}'.toLowerCase();
        return text.contains(kw) || extraKeywords.any((k) => text.contains(k));
      }).toList();
    }
    return result;
  }

  bool _similarName(String a, String b) {
    a = a.replaceAll(' ', '');
    b = b.replaceAll(' ', '');
    if (a.length < 2 || b.length < 2) return false;
    return a.contains(b) || b.contains(a);
  }

  double _distM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  static const _catMap = <String, List<String>>{
    '한식': ['한정식', '삼겹살', '갈비', '비빔밥', '국밥', '삼계탕', '순두부'],
    '양식': ['이탈리안', '피자', '파스타', '스테이크', '버거'],
    '일식': ['초밥', '스시', '라멘', '돈까스', '우동', '소바', '이자카야'],
    '중식': ['중국', '짜장', '짬뽕', '탕수육', '양꼬치', '마라'],
    '카페': ['커피', '디저트', '베이커리', '빵집', '케이크', '브런치'],
    '분식': ['떡볶이', '순대', '김밥', '라면', '튀김', '어묵'],
    '치킨': ['닭', '후라이드', '양념치킨'],
    '해산물': ['횟집', '생선', '게장', '새우', '조개', '굴', '수산'],
  };
}
