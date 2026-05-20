// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mode_b_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modeBRepositoryHash() => r'f113cbbc3d668f28ca6e4923253d5fe6e39038e5';

/// See also [modeBRepository].
@ProviderFor(modeBRepository)
final modeBRepositoryProvider = Provider<ModeBRepository>.internal(
  modeBRepository,
  name: r'modeBRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$modeBRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ModeBRepositoryRef = ProviderRef<ModeBRepository>;
String _$foodSearchHash() => r'0d301d582d6365b5b702a2f81759ff4d7759235b';

/// See also [FoodSearch].
@ProviderFor(FoodSearch)
final foodSearchProvider =
    AutoDisposeNotifierProvider<FoodSearch, FoodSearchState>.internal(
      FoodSearch.new,
      name: r'foodSearchProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$foodSearchHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FoodSearch = AutoDisposeNotifier<FoodSearchState>;
String _$selectedFoodHash() => r'b11e5acfe10368a9755a6c55fc67084e9e7b4487';

/// See also [SelectedFood].
@ProviderFor(SelectedFood)
final selectedFoodProvider =
    AutoDisposeNotifierProvider<SelectedFood, FoodEntity?>.internal(
      SelectedFood.new,
      name: r'selectedFoodProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedFoodHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedFood = AutoDisposeNotifier<FoodEntity?>;
String _$routeSearchHash() => r'c629c578f7e86197b126a3d420ee0775373b7f05';

/// See also [RouteSearch].
@ProviderFor(RouteSearch)
final routeSearchProvider =
    AutoDisposeNotifierProvider<RouteSearch, RouteSearchState>.internal(
      RouteSearch.new,
      name: r'routeSearchProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$routeSearchHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RouteSearch = AutoDisposeNotifier<RouteSearchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
