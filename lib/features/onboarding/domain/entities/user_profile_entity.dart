import '../../../../core/models/body_metrics.dart';

class UserProfileEntity {
  const UserProfileEntity({
    this.heightCm = 170.0,
    this.weightKg = 65.0,
    this.age = 30,
    this.sex = 'male',
    this.preferredTransport = 'walk',
    this.preferredCategories = const [],
    this.preferredRegions = const ['전체'],
  });

  final double heightCm;
  final double weightKg;
  final int age;
  final String sex;
  final String preferredTransport;
  final List<String> preferredCategories;
  final List<String> preferredRegions;

  factory UserProfileEntity.fromJson(Map<String, dynamic> json) =>
      UserProfileEntity(
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 65.0,
        age: (json['age'] as num?)?.toInt() ?? 30,
        sex: json['sex'] as String? ?? 'male',
        preferredTransport: json['preferredTransport'] as String? ?? 'walk',
        preferredCategories:
            (json['preferredCategories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        preferredRegions:
            (json['preferredRegions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['전체'],
      );

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'sex': sex,
        'preferredTransport': preferredTransport,
        'preferredCategories': preferredCategories,
        'preferredRegions': preferredRegions,
      };

  UserProfileEntity copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    String? sex,
    String? preferredTransport,
    List<String>? preferredCategories,
    List<String>? preferredRegions,
  }) {
    return UserProfileEntity(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      preferredTransport: preferredTransport ?? this.preferredTransport,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredRegions: preferredRegions ?? this.preferredRegions,
    );
  }

  BodyMetrics toBodyMetrics() => BodyMetrics(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sex: sex,
      );
}
