import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/food_catalog_entity.dart';

/// food_catalog 컬렉션 CRUD.
///
/// 문서 ID = canonical_name (한글 표준명).
/// 카테고리 + search_count 복합 정렬 쿼리는 Firestore 복합 인덱스 필요:
///   category ASC + search_count DESC
class FoodFirestoreDatasource {
  // Firestore 범위 쿼리 접두어 검색용 Unicode 센티널
  static final _sentinel = String.fromCharCode(0xF8FF);

  final _col = FirebaseFirestore.instance.collection('food_catalog');

  Future<FoodCatalogEntity?> getByCanonicalName(String name) async {
    final doc = await _col.doc(name).get();
    if (!doc.exists) return null;
    return FoodCatalogEntity.fromFirestore(doc.data()!);
  }

  /// display_name 접두어 검색. 0xF8FF 센티널로 상한 지정.
  Future<List<FoodCatalogEntity>> searchByPrefix(
    String query, {
    String? category,
    int limit = 20,
  }) async {
    final snap = await _col
        .where('display_name', isGreaterThanOrEqualTo: query)
        .where('display_name', isLessThan: query + _sentinel)
        .limit(limit)
        .get();
    final results =
        snap.docs.map((d) => FoodCatalogEntity.fromFirestore(d.data())).toList();

    if (category == null || category == '전체') return results;
    return results.where((f) => f.category == category).toList();
  }

  Future<List<FoodCatalogEntity>> getPopular({
    String? category,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q;
    if (category != null && category != '전체') {
      q = _col
          .where('category', isEqualTo: category)
          .orderBy('search_count', descending: true)
          .limit(limit);
    } else {
      q = _col.orderBy('search_count', descending: true).limit(limit);
    }
    final snap = await q.get();
    return snap.docs
        .map((d) => FoodCatalogEntity.fromFirestore(d.data()))
        .toList();
  }

  Future<void> incrementCount(String canonicalName) async {
    await _col.doc(canonicalName).update({
      'search_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsert(Map<String, dynamic> data) async {
    final name = data['canonical_name'] as String;
    await _col.doc(name).set(data, SetOptions(merge: true));
  }

  Future<void> batchUpsert(List<Map<String, dynamic>> items) async {
    const chunkSize = 500;
    for (var i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, (i + chunkSize).clamp(0, items.length));
      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        final ref = _col.doc(item['canonical_name'] as String);
        batch.set(ref, item, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// search_count <= [maxCount] 이고 [before] 이전에 갱신된 비시드 항목 삭제.
  /// 복합 인덱스 불필요: search_count 단독 쿼리 후 클라이언트에서 is_seeded 필터링
  Future<int> pruneStale({
    required int maxCount,
    required DateTime before,
  }) async {
    try {
      final snap = await _col
          .where('search_count', isLessThanOrEqualTo: maxCount)
          .limit(100)
          .get();

      final cutoff = Timestamp.fromDate(before);
      final stale = snap.docs.where((d) {
        final ts = d.data()['updated_at'];
        return ts is Timestamp && ts.compareTo(cutoff) < 0;
      }).toList();

      if (stale.isEmpty) return 0;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in stale) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[Firestore] pruned ${stale.length} stale food items');
      return stale.length;
    } catch (e) {
      debugPrint('[Firestore] pruneStale error: $e');
      return 0;
    }
  }

  // ── 카테고리 컬렉션 ──────────────────────────────────────────────

  final _catCol =
      FirebaseFirestore.instance.collection('food_categories');

  Future<List<String>> getCategories() async {
    try {
      final snap =
          await _catCol.orderBy('order').get();
      if (snap.docs.isEmpty) return [];
      return snap.docs
          .map((d) => d.data()['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[Firestore] getCategories error: $e');
      return [];
    }
  }

  Future<void> ensureCategory(String name, {int order = 99}) async {
    try {
      final ref = _catCol.doc(name);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'name': name,
          'order': order,
          'is_builtin': false,
          'created_at': FieldValue.serverTimestamp(),
        });
        debugPrint('[Firestore] created new category: $name');
      }
    } catch (e) {
      debugPrint('[Firestore] ensureCategory error: $e');
    }
  }

}
