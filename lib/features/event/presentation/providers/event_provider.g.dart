// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eventRepositoryHash() => r'4109f7e42782cdf17ddb9e8e840ce51a7dcf7df5';

/// See also [eventRepository].
@ProviderFor(eventRepository)
final eventRepositoryProvider = Provider<EventRepository>.internal(
  eventRepository,
  name: r'eventRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$eventRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EventRepositoryRef = ProviderRef<EventRepository>;
String _$homeEventsHash() => r'a0c3d25e3e4ec835e8e0833e13f931d2263e2144';

/// See also [HomeEvents].
@ProviderFor(HomeEvents)
final homeEventsProvider =
    AutoDisposeNotifierProvider<HomeEvents, HomeEventsState>.internal(
      HomeEvents.new,
      name: r'homeEventsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homeEventsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HomeEvents = AutoDisposeNotifier<HomeEventsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
