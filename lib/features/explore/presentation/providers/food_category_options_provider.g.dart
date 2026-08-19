// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_category_options_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$foodPreferenceCategoriesHash() =>
    r'077ae5c3f8e96eeb2b5e6ec0ef209fcae2ee96a0';

/// food_categories(Firestore)의 카테고리 목록('전체' 제외) — 온보딩·프로필 편집의
/// 선호 음식 선택 UI가 food_catalog과 동일한 taxonomy를 쓰도록 한다.
///
/// Copied from [foodPreferenceCategories].
@ProviderFor(foodPreferenceCategories)
final foodPreferenceCategoriesProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
      foodPreferenceCategories,
      name: r'foodPreferenceCategoriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$foodPreferenceCategoriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FoodPreferenceCategoriesRef =
    AutoDisposeFutureProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
