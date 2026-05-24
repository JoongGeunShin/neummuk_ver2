// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordRepositoryHash() => r'5f992469838cda275249836dabce2cf8e9b0dfc2';

/// See also [recordRepository].
@ProviderFor(recordRepository)
final recordRepositoryProvider = Provider<RecordRepository>.internal(
  recordRepository,
  name: r'recordRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recordRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecordRepositoryRef = ProviderRef<RecordRepository>;
String _$weekRecordsHash() => r'1b60e326c20d54ab3048ab798698241210ca1f92';

/// Raw week records — single Firestore fetch, cached by Riverpod.
///
/// Copied from [weekRecords].
@ProviderFor(weekRecords)
final weekRecordsProvider =
    AutoDisposeFutureProvider<List<DailyRecordEntity>>.internal(
      weekRecords,
      name: r'weekRecordsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$weekRecordsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WeekRecordsRef = AutoDisposeFutureProviderRef<List<DailyRecordEntity>>;
String _$weeklyDataHash() => r'5e0e230248afc8ddc316b4f35f0024d594d1527d';

/// 7-entry list (Mon–Sun) mapped for WeeklyChart widget.
///
/// Copied from [weeklyData].
@ProviderFor(weeklyData)
final weeklyDataProvider =
    AutoDisposeFutureProvider<List<WeeklyDataEntity>>.internal(
      weeklyData,
      name: r'weeklyDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$weeklyDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WeeklyDataRef = AutoDisposeFutureProviderRef<List<WeeklyDataEntity>>;
String _$weeklySummaryHash() => r'6095c9e4f68b30e332b4ddddbe85e3412a80f717';

/// Summary stats for the 3 stat cards at the top of the record screen.
///
/// Copied from [weeklySummary].
@ProviderFor(weeklySummary)
final weeklySummaryProvider =
    AutoDisposeFutureProvider<({double kcal, double km, int days})>.internal(
      weeklySummary,
      name: r'weeklySummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$weeklySummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WeeklySummaryRef =
    AutoDisposeFutureProviderRef<({double kcal, double km, int days})>;
String _$todayRecordHash() => r'6db99f523665cb9afd9550a442d569f08db3b11c';

/// Today's record, or null if none saved yet.
///
/// Copied from [todayRecord].
@ProviderFor(todayRecord)
final todayRecordProvider =
    AutoDisposeFutureProvider<DailyRecordEntity?>.internal(
      todayRecord,
      name: r'todayRecordProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$todayRecordHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayRecordRef = AutoDisposeFutureProviderRef<DailyRecordEntity?>;
String _$badgesHash() => r'027238769f498b23d244acb8ef393dd90622d473';

/// See also [badges].
@ProviderFor(badges)
final badgesProvider = AutoDisposeFutureProvider<List<BadgeEntity>>.internal(
  badges,
  name: r'badgesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$badgesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BadgesRef = AutoDisposeFutureProviderRef<List<BadgeEntity>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
