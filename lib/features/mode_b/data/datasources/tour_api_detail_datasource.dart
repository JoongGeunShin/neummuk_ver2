import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';

class SpotDetailData {
  const SpotDetailData({
    this.overview,
    this.tel,
    this.homepageUrl,
    this.images = const [],
    this.operatingInfo,
  });

  final String? overview;
  final String? tel;
  final String? homepageUrl;
  final List<String> images;
  final String? operatingInfo;
}

class TourApiDetailDatasource {
  static const _base = AppConstants.tourApiBaseUrl;

  /// TourAPI contentId 기반 상세 정보 (detailCommon2 + detailInfo2 + detailImage2) 병렬 호출
  Future<SpotDetailData?> fetchDetail(String contentId, int contentTypeId) async {
    final key = AppEnv.dataGoKey;
    if (key.isEmpty) return null;

    try {
      final common = await _fetchCommon(key, contentId, contentTypeId);
      if (common == null) return null;

      // detailInfo2, detailImage2 병렬
      final opInfoFuture = _fetchOperatingInfo(key, contentId, contentTypeId);
      final imagesFuture = _fetchImages(key, contentId);
      final opInfo = await opInfoFuture;
      final extraImages = await imagesFuture;

      final overview = _clean(common['overview']?.toString());
      final tel = _clean(common['tel']?.toString());
      final rawHomepage = _clean(common['homepage']?.toString());
      final homepageUrl = _extractUrl(rawHomepage);

      final images = <String>[];
      final img1 = common['firstimage']?.toString() ?? '';
      final img2 = common['firstimage2']?.toString() ?? '';
      if (img1.isNotEmpty) images.add(img1);
      if (img2.isNotEmpty && img2 != img1) images.add(img2);
      for (final img in extraImages) {
        if (!images.contains(img)) images.add(img);
      }

      return SpotDetailData(
        overview: overview,
        tel: tel,
        homepageUrl: homepageUrl,
        images: images,
        operatingInfo: opInfo,
      );
    } catch (e) {
      debugPrint('[TourApiDetail] fetchDetail $contentId: $e');
      return null;
    }
  }

  /// 카카오 스팟 이름+좌표로 TourAPI 키워드 검색 → 이미지 URL 반환 (없으면 null)
  Future<String?> findImageByKeyword(String name, double lat, double lng) async {
    final key = AppEnv.dataGoKey;
    if (key.isEmpty) return null;

    try {
      final uri = Uri.parse('$_base/searchKeyword2').replace(queryParameters: {
        'serviceKey': key,
        'keyword': name,
        'mapX': '$lng',
        'mapY': '$lat',
        'radius': '500',
        'numOfRows': '1',
        'pageNo': '1',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        '_type': 'json',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) return null;

      final item = raw is List
          ? (raw.isNotEmpty ? raw[0] as Map<String, dynamic> : null)
          : raw as Map<String, dynamic>;

      final img = item?['firstimage']?.toString() ?? '';
      return img.isEmpty ? null : img;
    } catch (e) {
      debugPrint('[TourApiDetail] findImageByKeyword "$name": $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchCommon(
      String key, String contentId, int typeId) async {
    try {
      // detailCommon2는 v4.3 기준 contentTypeId / defaultYN / firstImageYN /
      // addrinfoYN / overviewYN 등 옵션 파라미터를 하나라도 넘기면
      // INVALID_REQUEST_PARAMETER_ERROR로 아이템이 통째로 비어 온다. 필수
      // 파라미터만 전달할 것 (tour_api_event_detail_datasource.dart와 동일 이슈).
      final uri = Uri.parse('$_base/detailCommon2').replace(queryParameters: {
        'serviceKey': key,
        'contentId': contentId,
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        '_type': 'json',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) return null;

      return raw is List
          ? (raw.isNotEmpty ? raw[0] as Map<String, dynamic> : null)
          : raw as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[TourApiDetail] detailCommon2 $contentId: $e');
      return null;
    }
  }

  Future<String?> _fetchOperatingInfo(
      String key, String contentId, int typeId) async {
    try {
      final uri = Uri.parse('$_base/detailInfo2').replace(queryParameters: {
        'serviceKey': key,
        'contentId': contentId,
        'contentTypeId': '$typeId',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        '_type': 'json',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) return null;

      final items = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [raw as Map<String, dynamic>];

      return _buildOperatingInfo(items, typeId);
    } catch (e) {
      debugPrint('[TourApiDetail] detailInfo2 $contentId: $e');
      return null;
    }
  }

  Future<List<String>> _fetchImages(String key, String contentId) async {
    try {
      final uri = Uri.parse('$_base/detailImage2').replace(queryParameters: {
        'serviceKey': key,
        'contentId': contentId,
        'imageYN': 'Y',
        'numOfRows': '5',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        '_type': 'json',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      if (res.body.trimLeft().startsWith('<')) return [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['response']?['body']?['items']?['item'];
      if (raw == null) return [];

      final items = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : [raw as Map<String, dynamic>];

      return items
          .map((i) => i['originimgurl']?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[TourApiDetail] detailImage2 $contentId: $e');
      return [];
    }
  }

  String? _buildOperatingInfo(List<Map<String, dynamic>> items, int typeId) {
    if (items.isEmpty) return null;
    final m = items.first;
    final parts = <String>[];

    switch (typeId) {
      case 12: // 관광지
        final usefee = _clean(m['usefee']?.toString());
        final usetime = _clean(m['usetime']?.toString());
        final restdate = _clean(m['restdate']?.toString());
        final parking = _clean(m['parking']?.toString());
        if (usefee != null) parts.add('이용요금  $usefee');
        if (usetime != null) parts.add('이용시간  $usetime');
        if (restdate != null) parts.add('휴무일  $restdate');
        if (parking != null) parts.add('주차  $parking');
      case 14: // 문화시설
        final usefee = _clean(m['usefee']?.toString());
        final usetime = _clean(m['usetimeculture']?.toString());
        final restdate = _clean(m['restdateculture']?.toString());
        if (usefee != null) parts.add('이용요금  $usefee');
        if (usetime != null) parts.add('이용시간  $usetime');
        if (restdate != null) parts.add('휴무일  $restdate');
      case 15: // 행사/공연/축제
        final start = _clean(m['eventstartdate']?.toString());
        final end = _clean(m['eventenddate']?.toString());
        final placea = _clean(m['placea']?.toString());
        final usetime = _clean(m['usetimefestival']?.toString());
        if (start != null && end != null) {
          parts.add('기간  ${_fmtDate(start)} ~ ${_fmtDate(end)}');
        }
        if (placea != null) parts.add('장소  $placea');
        if (usetime != null) parts.add('이용시간  $usetime');
      case 28: // 레포츠
        final usefee = _clean(m['usefeeleports']?.toString());
        final usetime = _clean(m['usetimeleports']?.toString());
        if (usefee != null) parts.add('이용요금  $usefee');
        if (usetime != null) parts.add('이용시간  $usetime');
      case 38: // 쇼핑
        final opentime = _clean(m['opentime']?.toString());
        final shopguide = _clean(m['shopguide']?.toString());
        if (opentime != null) parts.add('영업시간  $opentime');
        if (shopguide != null) parts.add(shopguide);
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  String _fmtDate(String raw) {
    if (raw.length == 8) {
      return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
    }
    return raw;
  }

  String? _clean(String? s) {
    if (s == null) return null;
    final trimmed = s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;
    return trimmed.replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  String? _extractUrl(String? raw) {
    if (raw == null) return null;
    // TourAPI homepage 필드는 <a href="...">...</a> 형태로 올 수 있음
    final dq = RegExp(r'href="([^"]+)"').firstMatch(raw);
    if (dq != null) return dq.group(1);
    final sq = RegExp("href='([^']+)'").firstMatch(raw);
    if (sq != null) return sq.group(1);
    if (raw.startsWith('http')) return raw.trim();
    return null;
  }
}
