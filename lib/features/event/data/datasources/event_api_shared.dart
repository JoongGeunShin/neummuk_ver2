class EventApiConstants {
  const EventApiConstants._();
  static const int contentTypeId = 15;
}


DateTime? parseTourApiDate(String? s) {
  if (s == null || s.length < 8) return null;
  try {
    return DateTime(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
    );
  } catch (_) {
    return null;
  }
}
