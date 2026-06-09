// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mode_b_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modeBRepositoryHash() => r'e2eb455288d4ab7325fc238cb7b3e504db0c3e68';

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
String _$selectedFoodHash() => r'd755a8f87594206cc079e132ca013f87d515ace1';

/// See also [SelectedFood].
@ProviderFor(SelectedFood)
final selectedFoodProvider =
    NotifierProvider<SelectedFood, FoodEntity?>.internal(
      SelectedFood.new,
      name: r'selectedFoodProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedFoodHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedFood = Notifier<FoodEntity?>;
String _$routeSearchHash() => r'60b9dce29a5e341ebfd3e377e31a724010085d67';

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
