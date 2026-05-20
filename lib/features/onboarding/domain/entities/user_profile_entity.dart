class UserProfileEntity {
  const UserProfileEntity({
    this.heightCm = 170.0,
    this.weightKg = 65.0,
    this.sex = 'male',
    this.preferredTransport = 'walk',
    this.preferredCategories = const ['한식'],
  });

  final double heightCm;
  final double weightKg;
  final String sex;
  final String preferredTransport;
  final List<String> preferredCategories;

  factory UserProfileEntity.fromJson(Map<String, dynamic> json) =>
      UserProfileEntity(
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 65.0,
        sex: json['sex'] as String? ?? 'male',
        preferredTransport: json['preferredTransport'] as String? ?? 'walk',
        preferredCategories:
            (json['preferredCategories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['한식'],
      );

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'sex': sex,
        'preferredTransport': preferredTransport,
        'preferredCategories': preferredCategories,
      };

  UserProfileEntity copyWith({
    double? heightCm,
    double? weightKg,
    String? sex,
    String? preferredTransport,
    List<String>? preferredCategories,
  }) {
    return UserProfileEntity(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      sex: sex ?? this.sex,
      preferredTransport: preferredTransport ?? this.preferredTransport,
      preferredCategories: preferredCategories ?? this.preferredCategories,
    );
  }
}
