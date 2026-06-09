// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explore_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$foodCatalogRepositoryHash() =>
    r'aeb13ba59ce4061b4fe86f8ea04775e20e4b2d0f';

/// See also [foodCatalogRepository].
@ProviderFor(foodCatalogRepository)
final foodCatalogRepositoryProvider = Provider<FoodCatalogRepository>.internal(
  foodCatalogRepository,
  name: r'foodCatalogRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$foodCatalogRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FoodCatalogRepositoryRef = ProviderRef<FoodCatalogRepository>;
String _$exploreHash() => r'371835f193cbd8c11b2359b0412b5d4c89fb6719';

/// See also [Explore].
@ProviderFor(Explore)
final exploreProvider =
    AutoDisposeNotifierProvider<Explore, ExploreState>.internal(
      Explore.new,
      name: r'exploreProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$exploreHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Explore = AutoDisposeNotifier<ExploreState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
