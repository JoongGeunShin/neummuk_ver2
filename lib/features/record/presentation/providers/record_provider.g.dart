// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordRepositoryHash() => r'67a590507c90c6d2c382a82f84ba8b99dc5f19c8';

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
String _$weeklyDataHash() => r'9e50998d519bd77e3a5cce3b2adfbd69f7c397ea';

/// See also [weeklyData].
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
String _$badgesHash() => r'be95bc08d2e5b39a82063556d2ee6bf1e4823ce8';

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
