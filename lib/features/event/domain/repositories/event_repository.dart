import '../entities/event_entity.dart';

abstract class EventRepository {
  Future<List<EventEntity>> getUpcomingEvents({int numOfRows = 8});

  Future<List<EventEntity>> getNearbyUpcomingEvents({
    required double lat,
    required double lng,
    int numOfRows = 8,
  });
}
