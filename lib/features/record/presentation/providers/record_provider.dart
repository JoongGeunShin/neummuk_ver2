import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/record_repository_impl.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/weekly_data_entity.dart';

part 'record_provider.g.dart';

@Riverpod(keepAlive: true)
RecordRepository recordRepository(RecordRepositoryRef ref) => RecordRepositoryImpl();

// weeklyData(ref) → generates weeklyDataProvider (AsyncValue<List<WeeklyDataEntity>>)
@riverpod
Future<List<WeeklyDataEntity>> weeklyData(WeeklyDataRef ref) =>
    ref.read(recordRepositoryProvider).getWeeklyData();

// badges(ref) → generates badgesProvider (AsyncValue<List<BadgeEntity>>)
@riverpod
Future<List<BadgeEntity>> badges(BadgesRef ref) =>
    ref.read(recordRepositoryProvider).getBadges();
