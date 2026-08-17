import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';

part 'event_provider.g.dart';

@Riverpod(keepAlive: true)
EventRepository eventRepository(EventRepositoryRef ref) => EventRepositoryImpl();

// ─── Home events state ────────────────────────────────────────

class HomeEventsState {
  const HomeEventsState({
    this.events = const [],
    this.isLoading = false,
    this.hasLocation = false,
    this.canRequestLocation = true,
  });

  final List<EventEntity> events;
  final bool isLoading;
  final bool hasLocation;
  /// false일 때 "내 주변 보기" 버튼 숨김 (deniedForever)
  final bool canRequestLocation;

  HomeEventsState copyWith({
    List<EventEntity>? events,
    bool? isLoading,
    bool? hasLocation,
    bool? canRequestLocation,
  }) =>
      HomeEventsState(
        events: events ?? this.events,
        isLoading: isLoading ?? this.isLoading,
        hasLocation: hasLocation ?? this.hasLocation,
        canRequestLocation: canRequestLocation ?? this.canRequestLocation,
      );
}

@riverpod
class HomeEvents extends _$HomeEvents {
  @override
  HomeEventsState build() {
    Future.microtask(_loadInitial);
    return const HomeEventsState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    final repo = ref.read(eventRepositoryProvider);

    // 전국 임박 행사가 기본값 — 위치 권한 보유 여부와 무관하게 항상 이 상태로 시작
    final events = await repo.getUpcomingEvents();
    state = state.copyWith(events: events, isLoading: false);

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(canRequestLocation: false);
      return;
    }
    // 이미 위치 권한이 있다면 팝업 없이 마지막으로 알려진 위치로
    // 전국 리스트에도 거리만 조용히 채워준다 (목록 자체는 그대로 전국 유지)
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && !state.hasLocation) {
        state = state.copyWith(events: _withDistances(state.events, pos));
      }
    }
  }

  Future<void> _loadNearby() async {
    state = state.copyWith(isLoading: true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 8));

      final repo = ref.read(eventRepositoryProvider);
      final events = await repo.getNearbyUpcomingEvents(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      state = state.copyWith(
        events: _withDistances(events, pos),
        isLoading: false,
        hasLocation: true,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 전국 임박 행사로 되돌아가기
  Future<void> resetToUpcoming() async {
    state = state.copyWith(isLoading: true, hasLocation: false);
    final events = await ref.read(eventRepositoryProvider).getUpcomingEvents();

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        state = state.copyWith(events: _withDistances(events, pos), isLoading: false);
        return;
      }
    }
    state = state.copyWith(events: events, isLoading: false);
  }

  /// 위치·행사 목록 출처와 무관하게 거리는 항상 동일한 방식(Haversine)으로 계산한다.
  List<EventEntity> _withDistances(List<EventEntity> events, Position pos) {
    return events.map((e) {
      if (e.lat == null || e.lng == null) return e;
      final meters =
          haversineDistanceM(pos.latitude, pos.longitude, e.lat!, e.lng!)
              .round();
      return e.copyWith(distanceFromUserM: meters);
    }).toList();
  }

  /// 홈 화면 "내 주변 보기" 버튼 탭 시 호출
  Future<void> requestLocationAndRefresh() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(canRequestLocation: false);
      return;
    }
    if (permission == LocationPermission.denied) return;

    await _loadNearby();
  }
}
