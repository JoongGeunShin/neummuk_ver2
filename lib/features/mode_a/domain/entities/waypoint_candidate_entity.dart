/// 경유지 추천 후보 (TourAPI 관광지/레포츠 + 우회 거리·칼로리 계산 결과)
class WaypointCandidateEntity {
  const WaypointCandidateEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.imageUrl,
    required this.category,
    required this.detourSec,
    required this.detourKm,
    required this.extraKcal,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? imageUrl;
  final String category;

  /// 경유로 인한 추가 소요 시간 (초)
  final int detourSec;

  /// 경유로 인한 추가 거리 (km)
  final double detourKm;

  /// 경유로 인한 추가 소모 칼로리
  final int extraKcal;

  String get detourLabel {
    final mins = (detourSec / 60).ceil();
    final km = detourKm.toStringAsFixed(1);
    // ignore: unnecessary_brace_in_string_interps
    return '+${km}km · +${mins}분';
  }
}
