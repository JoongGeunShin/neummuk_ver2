import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/record_repository_impl.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/daily_record_entity.dart';
import '../../domain/entities/weekly_data_entity.dart';

part 'record_provider.g.dart';

@Riverpod(keepAlive: true)
RecordRepository recordRepository(Ref ref) => RecordRepositoryImpl();

/// Raw week records — single Firestore fetch, cached by Riverpod.
@riverpod
Future<List<DailyRecordEntity>> weekRecords(Ref ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  return ref.read(recordRepositoryProvider).getWeekRecords(uid);
}

/// 7-entry list (Mon–Sun) mapped for WeeklyChart widget.
@riverpod
Future<List<WeeklyDataEntity>> weeklyData(Ref ref) async {
  final records = await ref.watch(weekRecordsProvider.future);
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  return List.generate(7, (i) {
    final date = monday.add(Duration(days: i));
    final key = date.toIso8601String().substring(0, 10);
    final rec = records.where((r) => r.date == key).firstOrNull;
    return WeeklyDataEntity(
      label: labels[i],
      burn: rec?.caloriesKcal.round() ?? 0,
      food: 0,
      isToday: i == now.weekday - 1,
    );
  });
}

/// Summary stats for the 3 stat cards at the top of the record screen.
@riverpod
Future<({double kcal, double km, int days})> weeklySummary(Ref ref) async {
  final records = await ref.watch(weekRecordsProvider.future);
  return (
    kcal: records.fold(0.0, (s, r) => s + r.caloriesKcal),
    km: records.fold(0.0, (s, r) => s + r.distanceM) / 1000,
    days: records.where((r) => r.steps > 0).length,
  );
}

/// Today's record, or null if none saved yet.
@riverpod
Future<DailyRecordEntity?> todayRecord(Ref ref) async {
  final records = await ref.watch(weekRecordsProvider.future);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return records.where((r) => r.date == today).firstOrNull;
}

@riverpod
Future<List<BadgeEntity>> badges(Ref ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) {
    return const [
      BadgeEntity(id: 'b1', name: '첫걸음', desc: '첫 산책 완료', icon: '👟', earned: false),
      BadgeEntity(id: 'b2', name: '한식 마니아', desc: '한식 10회 추천', icon: '🍱', earned: false),
      BadgeEntity(id: 'b3', name: '1만보 클럽', desc: '하루 10,000보', icon: '🏃', earned: false),
      BadgeEntity(id: 'b4', name: '5km 챌린저', desc: '5km 이상 1회', icon: '🚶', earned: false),
      BadgeEntity(id: 'b5', name: '주3일 루틴', desc: '한 주에 3일 이상 활동', icon: '📅', earned: false),
      BadgeEntity(id: 'b6', name: '칼로리 마스터', desc: '하루 500kcal 소모', icon: '⚖️', earned: false),
    ];
  }
  return ref.read(recordRepositoryProvider).getBadges(uid);
}
