import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/env/app_env.dart';
import '../../domain/entities/event_detail_entity.dart';
import 'event_api_shared.dart';

class TourApiEventDetailDatasource {
  /// detailCommon2 + detailIntro2 병렬 조회
  Future<EventDetailEntity> fetchDetail(
      String contentId, {
      String? fallbackImageUrl,
    }) async {
    final key = AppEnv.dataGoKey;

    final commonUri =
        Uri.parse('${AppConstants.tourApiBaseUrl}/detailCommon2').replace(
      queryParameters: {
        'serviceKey': key,
        'contentId': contentId,
        'contentTypeId': '${EventApiConstants.contentTypeId}',
        'MobileOS': 'ETC',
        'MobileApp': 'neummuk',
        'defaultYN': 'Y',
        'firstImageYN': 'Y',
        'mapinfoYN': 'Y',
        'overviewYN': 'Y',
        '_type': 'json',
      },
    );

    final introUri =
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
      final results = await Future.wait([
        http.get(commonUri).timeout(const Duration(seconds: 10)),
        http.get(introUri).timeout(const Duration(seconds: 10)),
      ]);

      final commonBody = _parseBody(results[0]);
      final introBody = _parseBody(results[1]);

      final common = _item(commonBody);
      final intro = _item(introBody);

      debugPrint('[EventDetail] contentId=$contentId common=${common != null} intro=${intro != null}');

      return EventDetailEntity(
        contentId: contentId,
        title: common?['title']?.toString() ?? '',
        addr: _join(common?['addr1'], common?['addr2']),
        tel: common?['tel']?.toString(),
        homepage: _stripHtml(common?['homepage']?.toString()),
        overview: _stripHtml(common?['overview']?.toString()),
        imageUrl: common?['firstimage']?.toString(),
        fallbackImageUrl: fallbackImageUrl,
        lat: double.tryParse(common?['mapy']?.toString() ?? ''),
        lng: double.tryParse(common?['mapx']?.toString() ?? ''),
        agelimit: _text(intro?['agelimit']),
        bookingplace: _text(intro?['bookingplace']),
        discountinfo: _stripHtml(intro?['discountinfofestival']?.toString()),
        startDate: parseTourApiDate(intro?['eventstartdate']?.toString()),
        endDate: parseTourApiDate(intro?['eventenddate']?.toString()),
        eventplace: _text(intro?['eventplace']),
        eventhomepage: _stripHtml(intro?['eventhomepage']?.toString()),
        festivalgrade: _text(intro?['festivalgrade']),
        placeinfo: _stripHtml(intro?['placeinfo']?.toString()),
        playtime: _text(intro?['playtime']),
        program: _stripHtml(intro?['program']?.toString()),
        spendtime: _text(intro?['spendtimefestival']),
      );
    } catch (e) {
      debugPrint('[EventDetail] error: $e');
      return EventDetailEntity(
        contentId: contentId,
        title: '',
        fallbackImageUrl: fallbackImageUrl,
      );
    }
  }

  Map<String, dynamic>? _parseBody(http.Response res) {
    if (res.statusCode != 200) return null;
    if (res.body.trimLeft().startsWith('<')) return null;
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _item(Map<String, dynamic>? body) {
    final raw = body?['response']?['body']?['items']?['item'];
    if (raw == null) return null;
    if (raw is List) return raw.isNotEmpty ? raw.first as Map<String, dynamic> : null;
    return Map<String, dynamic>.from(raw as Map);
  }

  String? _text(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  String? _join(dynamic a, dynamic b) {
    final sa = a?.toString().trim() ?? '';
    final sb = b?.toString().trim() ?? '';
    if (sa.isEmpty && sb.isEmpty) return null;
    if (sb.isEmpty) return sa;
    return '$sa $sb'.trim();
  }

  String? _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
