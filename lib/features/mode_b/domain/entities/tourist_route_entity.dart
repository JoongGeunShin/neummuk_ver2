class TouristRouteEntity {
  const TouristRouteEntity({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.durationMinutes,
    required this.kcal,
    required this.type,
    this.tags = const [],
  });

  final String id;
  final String name;
  final double distanceKm;
  final int durationMinutes;
  final int kcal;
  final String type; // '도보' | '자전거'
  final List<String> tags;

  bool get isWalking => type == '도보';
}
