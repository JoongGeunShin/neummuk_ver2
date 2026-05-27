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
    double searchLat = latitude;
    double searchLng = longitude;
    String? effectiveKeyword = keyword;

    // 자유 텍스트 검색에 위치 힌트가 있으면:
    // 1) 위치 부분을 지오코딩해서 검색 중심 좌표를 얻는다.
    // 2) 위치 부분을 제거한 나머지 키워드만 API에 보낸다.
    // ex) "위례역 술집" → 위례역 좌표 + "술집" 검색 → 결과 많음
    if (keyword != null && keyword.isNotEmpty && !isCategory) {
      final parsed = _parseQuery(keyword);
      if (parsed.location != null) {
        final coords = await _geocodeLocation(parsed.location!)
            .catchError((_) => null);
        if (coords != null) {
          searchLat = coords.$1;
          searchLng = coords.$2;
          effectiveKeyword = parsed.keyword.isNotEmpty ? parsed.keyword : null;
        }
      }
    }

    final results = await Future.wait([
      _fetchTourApi(searchLat, searchLng, radiusMeters, effectiveKeyword, isCategory)
          .catchError((_) => <PlaceEntity>[]),
      _fetchKakaoLocal(searchLat, searchLng, radiusMeters, effectiveKeyword)
          .catchError((_) => <PlaceEntity>[]),
    ]);
    return _merge(results[0], results[1], effectiveKeyword, isCategory: isCategory);
  }

  // 쿼리를 위치 부분과 키워드 부분으로 분리한다.
  // "위례역 술집" → (location: "위례역", keyword: "술집")
  // "제주도 맛집" → (location: "제주도", keyword: "맛집")
  // "가성비 술집" → (location: null, keyword: "가성비 술집")
  static ({String? location, String keyword}) _parseQuery(String query) {
    final match = RegExp(
      r'[가-힣]+(?:도|시|군|구|읍|면|리|동|역|로|가|길|앞|근처|주변|일대|지역|인근)',
    ).firstMatch(query);
    if (match == null) return (location: null, keyword: query.trim());
    final location = match.group(0)!;
    final remaining = query.replaceFirst(location, '').trim();
    return (location: location, keyword: remaining);
  }

  // 위치 텍스트를 Kakao 키워드 검색으로 지오코딩 → (lat, lng) 반환
  Future<(double, double)?> _geocodeLocation(String locationText) async {
    final response = await http.get(
      Uri.parse('${AppConstants.kakaoLocalBaseUrl}/search/keyword.json')
          .replace(queryParameters: {'query': locationText, 'size': '1'}),
      headers: {'Authorization': 'KakaoAK $_kakaoKey'},
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['documents'] as List? ?? [];
    if (docs.isEmpty) return null;
    final x = double.tryParse(docs[0]['x']?.toString() ?? '');
    final y = double.tryParse(docs[0]['y']?.toString() ?? '');
    if (x == null || y == null) return null;
    return (y, x); // (lat, lng)
  }

  // TourAPI 공공데이터 ———————————————————————————————————————————
  Future<List<PlaceEntity>> _fetchTourApi(
    double lat,
    double lng,
    int radius,
    String? keyword,
    bool isCategory,
  ) async {
    final String path;
    final Map<String, String> params;

    if (keyword != null && keyword.isNotEmpty && !isCategory) {
      // 자유 텍스트 검색: contentTypeId 제거 → 모든 콘텐츠 유형 포함
      // lat/lng은 호출부에서 이미 지오코딩된 올바른 좌표가 넘어옴
      path = 'searchKeyword2';
      params = {
        'numOfRows': '30',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'neummuk',
        '_type': 'json',
        'keyword': keyword,
        'mapX': lng.toStringAsFixed(7),
        'mapY': lat.toStringAsFixed(7),
        'radius': radius.clamp(0, 20000).toString(),
        'arrange': 'A',
      };
    } else {
      // 카테고리 칩 or 초기 브라우징: 위치 기반, contentTypeId 없음 → 전체 유형
      path = 'locationBasedList2';
      params = {
        'numOfRows': '30',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'neummuk',
        '_type': 'json',
        'mapX': lng.toStringAsFixed(7),
        'mapY': lat.toStringAsFixed(7),
        'radius': radius.toString(),
        'arrange': 'S',
      };
      // 카테고리 칩 선택 시 키워드로 필터 (TourAPI는 키워드 파라미터 없이 위치 기반만 함)
    }

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url =
        '${AppConstants.tourApiBaseUrl}/$path?serviceKey=$_tourKey&$queryString';
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final body = json['response']?['body'];
    if (body == null) return [];

    final totalCount =
        int.tryParse(body['totalCount'].toString()) ?? 0;
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

  // 카카오 로컬 —————————————————————————————
  Future<List<PlaceEntity>> _fetchKakaoLocal(
    double lat,
    double lng,
    int radius,
    String? keyword,
  ) async {
    final String path;
    final Map<String, String> params;

    if (keyword != null && keyword.isNotEmpty) {
      // 자유 텍스트 검색: category_group_code 제거 → 모든 장소 유형 포함
      // lat/lng은 호출부에서 이미 지오코딩된 올바른 좌표가 넘어옴
      path = '/search/keyword.json';
      params = {
        'query': keyword,
        'x': lng.toString(),
        'y': lat.toString(),
        'radius': radius.toString(),
        'size': '15',
      };
    } else {
      // 초기 브라우징: FD6(음식점) + AT4(관광명소) 병렬 요청은 비용이 크므로
      // FD6 유지하되 TourAPI가 관광지를 커버함
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
      Uri.parse('${AppConstants.kakaoLocalBaseUrl}$path')
          .replace(queryParameters: params),
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
        address:
            roadAddr.isNotEmpty ? roadAddr : doc['address_name'] as String?,
        phone: doc['phone'] as String?,
        category: doc['category_name'] as String?,
        source: PlaceSource.kakaoLocal,
      );
    }).whereType<PlaceEntity>().toList();
  }

  List<PlaceEntity> _merge(
    List<PlaceEntity> tour,
    List<PlaceEntity> kakao,
    String? keyword, {
    bool isCategory = false,
  }) {
    final result = List<PlaceEntity>.from(tour);

    for (final kPlace in kakao) {
      final matchIdx = result.indexWhere((t) =>
          _distM(t.latitude, t.longitude, kPlace.latitude, kPlace.longitude) <
              150 &&
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

    // 카테고리 칩 선택 시에만 클라이언트 필터 적용.
    // 자유 텍스트 검색은 API가 이미 관련 결과를 돌려주므로 재필터하지 않는다.
    if (isCategory && keyword != null && keyword.isNotEmpty) {
      final kw = keyword.toLowerCase();
      final extraKeywords = _catMap[keyword] ?? [];
      return result.where((p) {
        if (p.source != PlaceSource.kakaoLocal) return true;
        final text = '${p.name} ${p.category ?? ''}'.toLowerCase();
        return text.contains(kw) ||
            extraKeywords.any((k) => text.contains(k));
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

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final response = await http.get(
      Uri.parse('${AppConstants.kakaoLocalBaseUrl}/geo/coord2address.json')
          .replace(queryParameters: {
        'x': longitude.toString(),
        'y': latitude.toString(),
      }),
      headers: {'Authorization': 'KakaoAK $_kakaoKey'},
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['documents'] as List? ?? [];
    if (docs.isEmpty) return null;
    final road = docs[0]['road_address'] as Map<String, dynamic>?;
    if (road != null) {
      final addr = road['address_name'] as String? ?? '';
      if (addr.isNotEmpty) return addr;
    }
    final addr = (docs[0]['address'] as Map<String, dynamic>?)?['address_name'] as String?;
    return addr?.isNotEmpty == true ? addr : null;
  }

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
