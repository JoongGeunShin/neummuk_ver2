import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/daily_record_entity.dart';

abstract interface class RecordRepository {
  Future<void> saveDailyRecord(String uid, DailyRecordEntity record);
  Future<void> addModeBCalories(String uid, String date, double kcal, double distanceM);
  Future<List<DailyRecordEntity>> getWeekRecords(String uid);
  Future<List<BadgeEntity>> getBadges(String uid);
}

class RecordRepositoryImpl implements RecordRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('daily_records');

  @override
  Future<void> saveDailyRecord(String uid, DailyRecordEntity record) =>
      _col(uid).doc(record.date).set({
        'date': record.date,
        'steps': record.steps,
        'distanceM': record.distanceM,
        'caloriesKcal': record.caloriesKcal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> addModeBCalories(
    String uid,
    String date,
    double kcal,
    double distanceM,
  ) =>
      _col(uid).doc(date).set(
        {
          'date': date,
          'steps': FieldValue.increment(0),
          'distanceM': FieldValue.increment(distanceM),
          'caloriesKcal': FieldValue.increment(kcal),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  /// Fetches this week's records (Mon → today) by document ID — no index needed.
  @override
  Future<List<DailyRecordEntity>> getWeekRecords(String uid) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    final snaps = await Future.wait(
      List.generate(now.weekday, (i) {
        final date = monday.add(Duration(days: i));
        final key = date.toIso8601String().substring(0, 10);
        return _col(uid).doc(key).get();
      }),
    );

    return snaps
        .where((s) => s.exists && s.data() != null)
        .map((s) => _fromMap(s.data()!))
        .toList();
  }

  /// Reads all records to derive badge achievements.
  @override
  Future<List<BadgeEntity>> getBadges(String uid) async {
    final snap = await _col(uid).get();
    final records = snap.docs.map((d) => _fromMap(d.data())).toList();

    final hasAny = records.isNotEmpty;
    final has10K = records.any((r) => r.steps >= 10000);
    final has5Km = records.any((r) => r.distanceM >= 5000);
    final has3DaysThisWeek = _activeDaysThisWeek(records) >= 3;

    return [
      BadgeEntity(id: 'b1', name: '첫걸음', desc: '첫 산책 완료', icon: '👟', earned: hasAny),
      BadgeEntity(id: 'b2', name: '한식 마니아', desc: '한식 10회 추천', icon: '🍱', earned: false),
      BadgeEntity(id: 'b3', name: '1만보 클럽', desc: '하루 10,000보', icon: '🏃', earned: has10K),
      BadgeEntity(id: 'b4', name: '5km 챌린저', desc: '5km 이상 1회', icon: '🚶', earned: has5Km),
      BadgeEntity(id: 'b5', name: '주3일 루틴', desc: '한 주에 3일 이상 활동', icon: '📅', earned: has3DaysThisWeek),
      BadgeEntity(id: 'b6', name: '칼로리 마스터', desc: '하루 500kcal 소모', icon: '⚖️', earned: records.any((r) => r.caloriesKcal >= 500)),
    ];
  }

  static DailyRecordEntity _fromMap(Map<String, dynamic> d) => DailyRecordEntity(
        date: d['date'] as String,
        steps: (d['steps'] as num).toInt(),
        distanceM: (d['distanceM'] as num).toDouble(),
        caloriesKcal: (d['caloriesKcal'] as num).toDouble(),
      );

  static int _activeDaysThisWeek(List<DailyRecordEntity> records) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    int count = 0;
    for (int i = 0; i < now.weekday; i++) {
      final key = monday.add(Duration(days: i)).toIso8601String().substring(0, 10);
      if (records.any((r) => r.date == key && r.steps > 0)) count++;
    }
    return count;
  }
}
