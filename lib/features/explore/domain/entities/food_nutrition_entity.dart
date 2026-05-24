class FoodNutritionEntity {
  const FoodNutritionEntity({
    required this.servingSizeG,
    required this.caloriesKcal,
    required this.carbsG,
    required this.sugarG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    this.saturatedFatG,
    this.cholesterolMg,
  });

  final double servingSizeG;
  final double caloriesKcal;
  final double carbsG;
  final double sugarG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double? saturatedFatG;
  final double? cholesterolMg;

  Map<String, dynamic> toMap() => {
        'serving_size_g': servingSizeG,
        'calories_kcal': caloriesKcal,
        'carbs_g': carbsG,
        'sugar_g': sugarG,
        'protein_g': proteinG,
        'fat_g': fatG,
        'sodium_mg': sodiumMg,
        if (saturatedFatG != null) 'saturated_fat_g': saturatedFatG,
        if (cholesterolMg != null) 'cholesterol_mg': cholesterolMg,
      };

  factory FoodNutritionEntity.fromMap(Map<String, dynamic> m) =>
      FoodNutritionEntity(
        servingSizeG: _d(m['serving_size_g']),
        caloriesKcal: _d(m['calories_kcal']),
        carbsG: _d(m['carbs_g']),
        sugarG: _d(m['sugar_g']),
        proteinG: _d(m['protein_g']),
        fatG: _d(m['fat_g']),
        sodiumMg: _d(m['sodium_mg']),
        saturatedFatG: m['saturated_fat_g'] != null ? _d(m['saturated_fat_g']) : null,
        cholesterolMg: m['cholesterol_mg'] != null ? _d(m['cholesterol_mg']) : null,
      );

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }
}
