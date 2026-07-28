// 큐레이션 음식 카탈로그(lib/features/explore/data/seed/food_seed_data.dart)를
// food_categories + food_catalog Firestore 컬렉션에 업서트한다. 식품안전처 API가
// 실시간 검색마다 만들어내던 중구난방 카테고리를 대체하는 고정 기준 데이터를
// 반영하는 용도 — 새 메뉴를 추가/수정했으면 이 커맨드 한 번으로 반영한다.
//
// 실행: flutter test test/seed_food_catalog/seed_food_catalog_test.dart
// (.env의 FIREBASE_WEB_API_KEY/FIREBASE_PROJECT_ID가 필요한 실제 네트워크 호출이라
// CI 대상이 아님)
//
// cloud_firestore/firebase_core Flutter 플러그인은 플랫폼 채널이 필요해 순수
// `flutter test`(에뮬레이터/기기 없이)에서 못 쓴다 — 대신 Firestore/Identity
// Toolkit REST API를 raw http로 직접 호출한다(mode_a/mode_b gpx export 테스트와
// 동일한 "flutter test를 스크립트로 쓰는" 패턴). 매번 새 익명 계정으로 인증하는데,
// firestore.rules가 food_catalog/food_categories에는 `request.auth != null`만
// 요구해 익명 사용자로도 충분하다.
//
// 재실행해도 안전(idempotent): 문서 ID가 canonical_name/카테고리명으로 고정이라
// 같은 항목은 덮어쓰기만 되고, food_catalog는 updateMask로 search_count 필드를
// 건드리지 않아 기존에 쌓인 검색 카운트가 리셋되지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:neummuk_ver2/features/explore/data/seed/food_seed_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('큐레이션 음식 카탈로그 → Firestore 시드', () async {
    await dotenv.load(fileName: '.env');

    final webApiKey = dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
    expect(webApiKey.isNotEmpty && projectId.isNotEmpty, isTrue,
        reason: '.env에 FIREBASE_WEB_API_KEY/FIREBASE_PROJECT_ID가 있는지 확인할 것');

    // ── 익명 인증 (Identity Toolkit REST) ─────────────────────────────────────
    final signUpRes = await http.post(
      Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$webApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'returnSecureToken': true}),
    );
    expect(signUpRes.statusCode, 200,
        reason: '익명 로그인 실패 — FIREBASE_WEB_API_KEY 확인 또는 Firebase 콘솔에서 '
            'Authentication > 로그인 방법 > 익명이 켜져 있는지 확인할 것: ${signUpRes.body}');
    final idToken = (jsonDecode(signUpRes.body) as Map<String, dynamic>)['idToken'] as String;

    // ── Firestore REST 문서 빌드 ───────────────────────────────────────────────
    // Write.update.name은 리소스 경로만 받는다("projects/..." — https:// 접두어 없이).
    // 실제 HTTP 요청 URL(:commit 호출)에만 "https://firestore.googleapis.com/v1/"를 붙인다.
    final docsPath = 'projects/$projectId/databases/(default)/documents';
    final baseUrl = 'https://firestore.googleapis.com/v1/$docsPath';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final categoryWrites = <Map<String, dynamic>>[];
    for (var i = 0; i < kFoodSeedCategories.length; i++) {
      final name = kFoodSeedCategories[i];
      categoryWrites.add({
        'update': {
          'name': '$docsPath/food_categories/$name',
          'fields': {
            'name': _str(name),
            'order': _int(i),
            'is_builtin': _bool(true),
            'created_at': _ts(nowIso),
          },
        },
        'updateMask': {
          'fieldPaths': ['name', 'order', 'is_builtin', 'created_at'],
        },
      });
    }

    // search_count는 원칙적으로 마스크에서 제외해 재실행해도 기존 검색 카운트를
    // 지키지만, updateMask에서 아예 뺀 필드는 Firestore가 신규 문서에도 만들어주지
    // 않는다 — 그러면 getPopular()의 orderBy('search_count')가 그 필드 자체가 없는
    // 문서를 결과에서 통째로 건너뛰어, 처음 시드되는 항목이 탐색탭에 하나도 안
    // 보이는 사고가 난다. 그래서 커밋 전에 batchGet으로 문서별 search_count 필드
    // "존재 여부"(문서 존재 여부가 아니라)를 확인해, 필드가 없는 문서에만
    // search_count: 0을 명시적으로 함께 써 넣는다.
    final canonicalNames =
        kFoodSeedItems.map((i) => i.name.replaceAll(' ', '')).toSet().toList();
    final hasSearchCount = <String>{};
    const getChunkSize = 500;
    for (var i = 0; i < canonicalNames.length; i += getChunkSize) {
      final chunk = canonicalNames.sublist(
          i, (i + getChunkSize).clamp(0, canonicalNames.length));
      final res = await http.post(
        Uri.parse('$baseUrl:batchGet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'documents': chunk.map((n) => '$docsPath/food_catalog/$n').toList(),
        }),
      );
      expect(res.statusCode, 200,
          reason: 'Firestore batchGet 실패: ${res.body}');
      for (final entry in jsonDecode(res.body) as List) {
        final found = (entry as Map<String, dynamic>)['found'];
        if (found is Map<String, dynamic>) {
          final name = (found['name'] as String).split('/').last;
          final fields = found['fields'] as Map<String, dynamic>? ?? {};
          if (fields.containsKey('search_count')) hasSearchCount.add(name);
        }
      }
    }

    final foodWrites = <Map<String, dynamic>>[];
    for (final item in kFoodSeedItems) {
      final canonicalName = item.name.replaceAll(' ', '');
      final needsSearchCountInit = !hasSearchCount.contains(canonicalName);
      final nutritionFields = <String, dynamic>{
        'serving_size_g': _num(item.servingSizeG),
        'calories_kcal': _num(item.caloriesKcal),
        'carbs_g': _num(item.carbsG),
        'sugar_g': _num(item.sugarG),
        'protein_g': _num(item.proteinG),
        'fat_g': _num(item.fatG),
        'sodium_mg': _num(item.sodiumMg),
        if (item.saturatedFatG != null) 'saturated_fat_g': _num(item.saturatedFatG!),
        if (item.cholesterolMg != null) 'cholesterol_mg': _num(item.cholesterolMg!),
      };
      foodWrites.add({
        'update': {
          'name': '$docsPath/food_catalog/$canonicalName',
          'fields': {
            'canonical_name': _str(canonicalName),
            'display_name': _str(item.name),
            'category': _str(item.category),
            'emoji': _str(item.emoji),
            'nutrition': _map(nutritionFields),
            'tags': _arr(const ['음식']),
            'is_seeded': _bool(true),
            'updated_at': _ts(nowIso),
            if (needsSearchCountInit) 'search_count': _int(0),
          },
        },
        'updateMask': {
          'fieldPaths': [
            'canonical_name', 'display_name', 'category', 'emoji',
            'nutrition', 'tags', 'is_seeded', 'updated_at',
            if (needsSearchCountInit) 'search_count',
          ],
        },
      });
    }

    final allWrites = [...categoryWrites, ...foodWrites];
    // ignore: avoid_print
    print('시드 대상: 카테고리 ${categoryWrites.length}개, 음식 ${foodWrites.length}개 '
        '(총 ${allWrites.length}건)');

    const chunkSize = 500; // Firestore :commit 1회 최대 쓰기 수
    var committed = 0;
    for (var i = 0; i < allWrites.length; i += chunkSize) {
      final chunk = allWrites.sublist(i, (i + chunkSize).clamp(0, allWrites.length));
      final res = await http.post(
        Uri.parse('$baseUrl:commit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'writes': chunk}),
      );
      expect(res.statusCode, 200,
          reason: 'Firestore commit 실패 — firestore.rules 배포 여부, 프로젝트 ID를 '
              '확인할 것: ${res.body}');
      committed += chunk.length;
      // ignore: avoid_print
      print('commit ${i ~/ chunkSize + 1}: ${chunk.length}건 완료 (누적 $committed/${allWrites.length})');
    }

    // ignore: avoid_print
    print('시드 완료: food_categories ${categoryWrites.length}개, '
        'food_catalog ${foodWrites.length}개 업서트됨');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

// ── Firestore REST Value 헬퍼 ────────────────────────────────────────────────

Map<String, dynamic> _str(String v) => {'stringValue': v};
Map<String, dynamic> _num(double v) => {'doubleValue': v};
Map<String, dynamic> _int(int v) => {'integerValue': v.toString()};
Map<String, dynamic> _bool(bool v) => {'booleanValue': v};
Map<String, dynamic> _ts(String iso8601Utc) => {'timestampValue': iso8601Utc};
Map<String, dynamic> _arr(List<String> v) => {
      'arrayValue': {
        'values': v.map(_str).toList(),
      },
    };
Map<String, dynamic> _map(Map<String, dynamic> fields) => {
      'mapValue': {'fields': fields},
    };
