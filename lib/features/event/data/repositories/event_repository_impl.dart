import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/tour_api_events_datasource.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl() : _datasource = TourApiEventsDatasource();

  final TourApiEventsDatasource _datasource;

  @override
  Future<List<EventEntity>> getUpcomingEvents({int numOfRows = 8}) =>
      _datasource.fetchUpcomingEvents(numOfRows: numOfRows);

  @override
  Future<List<EventEntity>> getNearbyUpcomingEvents({
    required double lat,
    required double lng,
    int numOfRows = 8,
  }) =>
      _datasource.fetchNearbyEvents(lat: lat, lng: lng, numOfRows: numOfRows);
}
