// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$placeRepositoryHash() => r'f703c065fc056a01681cfb16bfa186ccd41af176';

/// See also [placeRepository].
@ProviderFor(placeRepository)
final placeRepositoryProvider = AutoDisposeProvider<PlaceRepository>.internal(
  placeRepository,
  name: r'placeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$placeRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlaceRepositoryRef = AutoDisposeProviderRef<PlaceRepository>;
String _$mapSearchNotifierHash() => r'd92de14d589087677c95e5bc3483f24b3603702a';

/// See also [MapSearchNotifier].
@ProviderFor(MapSearchNotifier)
final mapSearchNotifierProvider =
    AutoDisposeNotifierProvider<MapSearchNotifier, MapSearchState>.internal(
      MapSearchNotifier.new,
      name: r'mapSearchNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mapSearchNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MapSearchNotifier = AutoDisposeNotifier<MapSearchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
