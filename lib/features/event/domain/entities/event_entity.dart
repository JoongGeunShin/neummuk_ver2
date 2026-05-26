class EventEntity {
  const EventEntity({
    required this.id,
    required this.name,
    this.addr,
    this.startDate,
    this.endDate,
    this.lat,
    this.lng,
    this.imageUrl,
    this.distanceFromUserM,
  });

  final String id;
  final String name;
  final String? addr;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final int? distanceFromUserM;

  // id 형식: 'event_${contentid}' → 순수 contentId 추출
  String get contentId => id.startsWith('event_') ? id.substring(6) : id;

  DateTime get _today =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool get isEnded {
    final end = endDate;
    if (end == null) return false;
    return end.isBefore(_today);
  }

  bool get isOngoing {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return now.isAfter(start) &&
        now.isBefore(end.add(const Duration(days: 1)));
  }

  int? get daysUntilStart {
    final start = startDate;
    if (start == null) return null;
    final startDay = DateTime(start.year, start.month, start.day);
    return startDay.difference(_today).inDays;
  }

  String get daysLabel {
    if (isEnded) return '종료됨';
    if (isOngoing) return '진행중';
    final d = daysUntilStart;
    if (d == null) return '';
    if (d == 0) return '오늘 시작';
    if (d > 0) return 'D-$d';
    return '';
  }

  String get dateRangeLabel {
    String fmt(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.month}.${dt.day.toString().padLeft(2, '0')}';
    }

    final s = fmt(startDate);
    final e = fmt(endDate);
    if (s.isEmpty && e.isEmpty) return '';
    if (s == e || e.isEmpty) return s;
    return '$s ~ $e';
  }
}
