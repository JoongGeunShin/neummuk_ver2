import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/bottom_nav.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../event/presentation/providers/event_provider.dart';
import '../../../event/presentation/widgets/event_card.dart';
import '../../../walk/presentation/providers/walk_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _mode = 'A';
  NavTab _activeTab = NavTab.home;

  static const double _fabSize = 56;
  Offset? _fabPos;
  bool _fabDragging = false;
  Offset _fabDragOrigin = Offset.zero;
  final GlobalKey _fabKey = GlobalKey();

  void _openMap() {
    ref.read(mapModeProvider.notifier).set(MapMode.explore);
    context.push('/map');
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      ref.read(walkSessionProvider.notifier).restart();
    }
  }

  void _handleTabChange(NavTab tab) {
    setState(() => _activeTab = tab);
    switch (tab) {
      case NavTab.search:
        context.go('/explore');

      case NavTab.record:
        context.go('/record');
      case NavTab.me:
        final user = ref.read(authStateProvider).valueOrNull;
        if (user == null) {
          setState(() => _activeTab = NavTab.home);
          context.go('/login');
        } else {
          context.go('/user');
        }
      case NavTab.home:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final walk = ref.watch(walkSessionProvider.select(
      (s) => (steps: s.steps, caloriesKcal: s.caloriesKcal, distanceM: s.distanceM),
    ));

    final screenSize = MediaQuery.sizeOf(context);
    final bottomNavH = context.hp(12);
    _fabPos ??= Offset(
      screenSize.width - _fabSize - 20,
      screenSize.height - _fabSize - bottomNavH - 16,
    );

    return DoubleBackToExit(
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.wp(5),
                              context.hp(1.5),
                              context.wp(5),
                              0,
                            ),
                            child: Row(
                              children: [
                                BrandLogo(size: context.wp(9)),
                                SizedBox(width: context.wp(2.5)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '내움먹',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: c.textMuted,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    Text(
                                      '죄책감 없이 먹어볼까요?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: c.text,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.wp(5),
                            context.hp(2),
                            context.wp(5),
                            0,
                          ),
                          child: SegmentedControl(
                            value: _mode,
                            options: const [
                              SegmentOption(
                                value: 'A',
                                label: '움직인 만큼 먹는다',
                                icon: Icons.directions_walk_rounded,
                              ),
                              SegmentOption(
                                value: 'B',
                                label: '먹기 위해 움직인다',
                                icon: Icons.restaurant_rounded,
                              ),
                            ],
                            onChanged: (v) => setState(() => _mode = v),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.wp(5),
                            context.hp(1.8),
                            context.wp(5),
                            0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              if (_mode == 'A') {
                                ref
                                    .read(mapModeProvider.notifier)
                                    .set(MapMode.modeA);
                                context.push('/map');
                              } else {
                                context.push('/mode-b');
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity == null) return;
                              if (details.primaryVelocity! < 0) {
                                if (_mode != 'B') {
                                  setState(() {
                                    _mode = 'B';
                                  });
                                }
                              }
                              else if (details.primaryVelocity! > 0) {
                                if (_mode != 'A') {
                                  setState(() {
                                    _mode = 'A';
                                  });
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [c.primary, c.secondary],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.primaryGlow,
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(context.wp(5)),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: -30,
                                    right: -20,
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0x1FFFFFFF),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _mode == 'A'
                                                  ? Icons
                                                        .directions_walk_rounded
                                                  : Icons.restaurant_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'MODE $_mode',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: context.hp(1)),
                                      Text(
                                        _mode == 'A'
                                            ? '출발→도착 입력하고\n딱 맞는 맛집 만나기'
                                            : '먹고 싶은 음식 골라\n최적의 산책 코스 찾기',
                                        style: TextStyle(
                                          fontSize: context.wp(6),
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: context.hp(0.8)),
                                      Text(
                                        _mode == 'A'
                                            ? '이동 칼로리 ±20% 범위 맛집 추천'
                                            : '음식 칼로리를 상쇄할 관광 루트 추천',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                      SizedBox(height: context.hp(1.2)),
                                      Row(
                                        children: [
                                          Text(
                                            _mode == 'A' ? '경로 입력하기' : '음식 고르기',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.wp(5),
                            context.hp(2.5),
                            context.wp(5),
                            0,
                          ),
                          child: Row(
                            children: [
                              _QuickStat(
                                icon: Icons.local_fire_department_rounded,
                                label: '오늘 소모',
                                value: walk.caloriesKcal.round().toString(),
                                unit: 'kcal',
                                color: c.primary,
                              ),
                              SizedBox(width: context.wp(2.5)),
                              _QuickStat(
                                icon: Icons.directions_walk_rounded,
                                label: '걸음',
                                value: _formatSteps(walk.steps),
                                unit: '보',
                                color: c.success,
                              ),
                              SizedBox(width: context.wp(2.5)),
                              _QuickStat(
                                icon: Icons.route_rounded,
                                label: '이동거리',
                                value: (walk.distanceM / 1000).toStringAsFixed(
                                  1,
                                ),
                                unit: 'km',
                                color: c.secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _EventsSection(),
                    ],
                  ),
                ),
                AppBottomNav(
                  activeTab: _activeTab,
                  onChanged: _handleTabChange,
                ),
              ],
            ),
            Positioned(
              left: _fabPos!.dx,
              top: _fabPos!.dy,
              child: GestureDetector(
                onTap: _openMap,
                onLongPressStart: (d) {
                  setState(() {
                    _fabDragging = true;
                    _fabDragOrigin = _fabPos!;
                  });
                },
                onLongPressMoveUpdate: (d) {
                  final newX = (_fabDragOrigin.dx + d.offsetFromOrigin.dx)
                      .clamp(0.0, screenSize.width - _fabSize);
                  final newY = (_fabDragOrigin.dy + d.offsetFromOrigin.dy)
                      .clamp(0.0, screenSize.height - _fabSize);
                  setState(() => _fabPos = Offset(newX, newY));
                },
                onLongPressEnd: (_) => setState(() => _fabDragging = false),
                onLongPressCancel: () => setState(() => _fabDragging = false),
                child: AnimatedScale(
                  scale: _fabDragging ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedContainer(
                    key: _fabKey,
                    duration: const Duration(milliseconds: 180),
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withValues(
                            alpha: _fabDragging ? 0.55 : 0.35,
                          ),
                          blurRadius: _fabDragging ? 20 : 10,
                          spreadRadius: _fabDragging ? 3 : 0,
                          offset: const Offset(0, 4),
                        ),
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// tourAPI 행사 공연 축제
class _EventsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final eventsState = ref.watch(homeEventsProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.wp(5),
              context.hp(3),
              context.wp(5),
              0,
            ),
            child: Row(
              children: [
                Text(
                  '행사 · 공연 · 축제',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                _EventLocationToggle(),
              ],
            ),
          ),
          SizedBox(
            height: context.hp(30),
            child: eventsState.isLoading && eventsState.events.isEmpty
                ? _EventsLoadingShimmer()
                : eventsState.events.isEmpty
                ? _EventsEmpty()
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      context.wp(5),
                      context.hp(1.5),
                      context.wp(5),
                      context.hp(3),
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: eventsState.events.length,
                    separatorBuilder: (_, __) => SizedBox(width: context.wp(3)),
                    itemBuilder: (ctx, i) {
                      final event = eventsState.events[i];
                      return EventCard(
                        event: event,
                        onTap: event.isEnded
                            ? () => ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('종료된 행사입니다'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              )
                            : () => ctx.push(
                                '/event/${event.contentId}',
                                extra: event.imageUrl,
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventsLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.wp(5),
        context.hp(1.5),
        context.wp(5),
        context.hp(3),
      ),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => SizedBox(width: context.wp(3)),
      itemBuilder: (_, __) => Container(
        width: context.wp(55),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.outline),
        ),
      ),
    );
  }
}

class _EventsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.festival_rounded, size: 32, color: c.textFaint),
          const SizedBox(height: 8),
          Text(
            '근처 행사 정보가 없습니다',
            style: TextStyle(
              color: c.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLocationToggle extends ConsumerWidget {
  const _EventLocationToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeEventsProvider);
    final notifier = ref.read(homeEventsProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleChip(
          label: '전국',
          active: !s.hasLocation,
          loading: s.isLoading && !s.hasLocation,
          onTap: s.hasLocation && !s.isLoading
              ? notifier.resetToUpcoming
              : null,
        ),
        const SizedBox(width: 6),
        if (s.canRequestLocation)
          _ToggleChip(
            label: '내 주변',
            icon: Icons.near_me_rounded,
            active: s.hasLocation,
            loading: s.isLoading && s.hasLocation,
            onTap: !s.hasLocation && !s.isLoading
                ? notifier.requestLocationAndRefresh
                : null,
          ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textColor = active ? Colors.white : c.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surfaceAlt,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: textColor,
                  ),
                ),
              )
            else if (icon != null) ...[
              Icon(icon, size: 11, color: textColor),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSteps(int n) {
  if (n < 1000) return '$n';
  return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
