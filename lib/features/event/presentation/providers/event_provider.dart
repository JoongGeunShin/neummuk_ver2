import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

    // 1. 위치 없이 전국 임박 행사 먼저 로드
    final events = await repo.getUpcomingEvents();
    state = state.copyWith(events: events, isLoading: false);

    // 2. 이미 권한이 있으면 조용히 위치 기반으로 업그레이드
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _loadNearby();
    } else if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(canRequestLocation: false);
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
        events: events,
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
    state = state.copyWith(events: events, isLoading: false);
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
