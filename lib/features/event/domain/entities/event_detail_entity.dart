class EventDetailEntity {
  const EventDetailEntity({
    required this.contentId,
    required this.title,
    this.addr,
    this.tel,
    this.homepage,
    this.overview,
    this.imageUrl,
    this.fallbackImageUrl,
    this.lat,
    this.lng,
    // detailIntro2 — contentTypeId=15 전용
    this.agelimit,
    this.bookingplace,
    this.discountinfo,
    this.startDate,
    this.endDate,
    this.eventplace,
    this.eventhomepage,
    this.festivalgrade,
    this.placeinfo,
    this.playtime,
    this.program,
    this.spendtime,
  });

  final String contentId;
  final String title;
  final String? addr;
  final String? tel;
  final String? homepage;
  final String? overview;
  final String? imageUrl;
  final String? fallbackImageUrl;

  String? get effectiveImageUrl =>
      imageUrl?.isNotEmpty == true ? imageUrl : fallbackImageUrl;
  final double? lat;
  final double? lng;

  final String? agelimit;
  final String? bookingplace;
  final String? discountinfo;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? eventplace;
  final String? eventhomepage;
  final String? festivalgrade;
  final String? placeinfo;
  final String? playtime;
  final String? program;
  final String? spendtime;

  String get dateRangeLabel {
    String fmt(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }
    final s = fmt(startDate);
    final e = fmt(endDate);
    if (s.isEmpty && e.isEmpty) return '';
    if (s == e || e.isEmpty) return s;
    return '$s ~ $e';
  }

  String? get effectiveHomepage => eventhomepage?.isNotEmpty == true
      ? eventhomepage
      : homepage?.isNotEmpty == true
          ? homepage
          : null;
}
