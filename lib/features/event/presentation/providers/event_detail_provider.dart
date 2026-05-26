import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/tour_api_event_detail_datasource.dart';
import '../../domain/entities/event_detail_entity.dart';

part 'event_detail_provider.g.dart';

@riverpod
Future<EventDetailEntity> eventDetail(
  EventDetailRef ref,
  String contentId, {
  String? fallbackImageUrl,
}) =>
    TourApiEventDetailDatasource().fetchDetail(
      contentId,
      fallbackImageUrl: fallbackImageUrl,
    );
