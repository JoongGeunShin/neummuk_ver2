import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_nutrition_entity.dart';

class FoodCatalogEntity {
  const FoodCatalogEntity({
    required this.canonicalName,
    required this.displayName,
    required this.category,
    required this.emoji,
    required this.nutrition,
    this.tags = const [],
    this.searchCount = 0,
    this.apiFoodCd,
  });

  final String canonicalName;
  final String displayName;
  final String category;
  final String emoji;
  final FoodNutritionEntity nutrition;
  /// API DB_CLASS_NM 기반 태그 (예: ["음식"], ["가공식품"])
  final List<String> tags;
  final int searchCount;
  final String? apiFoodCd;

  Map<String, dynamic> toFirestoreMap() => {
        'canonical_name': canonicalName,
        'display_name': displayName,
        'category': category,
        'emoji': emoji,
        'nutrition': nutrition.toMap(),
        'tags': tags,
        'search_count': searchCount,
        if (apiFoodCd != null) 'api_food_cd': apiFoodCd,
        'updated_at': FieldValue.serverTimestamp(),
      };

  factory FoodCatalogEntity.fromFirestore(Map<String, dynamic> m) {
    final rawNutrition = m['nutrition'];
    final nutrition = rawNutrition is Map<String, dynamic>
        ? FoodNutritionEntity.fromMap(rawNutrition)
        : const FoodNutritionEntity(
            servingSizeG: 100,
            caloriesKcal: 0,
            carbsG: 0,
            sugarG: 0,
            proteinG: 0,
            fatG: 0,
            sodiumMg: 0,
          );
    return FoodCatalogEntity(
      canonicalName: m['canonical_name'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '',
      category: m['category'] as String? ?? '기타',
      emoji: m['emoji'] as String? ?? '🍽️',
      nutrition: nutrition,
      tags: List<String>.from(m['tags'] as List? ?? []),
      searchCount: (m['search_count'] as num?)?.toInt() ?? 0,
      apiFoodCd: m['api_food_cd'] as String?,
    );
  }
}
