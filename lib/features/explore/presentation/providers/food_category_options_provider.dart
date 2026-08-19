import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'explore_provider.dart';

part 'food_category_options_provider.g.dart';

/// food_categories(Firestore)의 카테고리 목록('전체' 제외) — 온보딩·프로필 편집의
/// 선호 음식 선택 UI가 food_catalog과 동일한 taxonomy를 쓰도록 한다.
@riverpod
Future<List<String>> foodPreferenceCategories(FoodPreferenceCategoriesRef ref) async {
  final cats = await ref.watch(foodCatalogRepositoryProvider).getCategories();
  return cats.where((c) => c != '전체').toList();
}
