import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/bottom_nav.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mode_a/data/repositories/mode_a_repository_impl.dart' show mockRestaurants;
import '../../../mode_b/data/repositories/mode_b_repository_impl.dart' show mockRoutes;
import '../../../walk/presentation/providers/walk_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _mode = 'A';
  NavTab _activeTab = NavTab.home;

  void _handleTabChange(NavTab tab) {
    setState(() => _activeTab = tab);
    switch (tab) {
      case NavTab.search:
        context.go('/mode-b');
      case NavTab.record:
        context.go('/record');
      case NavTab.me:
        final user = ref.read(authStateProvider).valueOrNull;
        if (user == null || user.isGuest) {
          setState(() => _activeTab = NavTab.home);
          _showSignupDialog();
        } else {
          context.go('/user');
        }
      case NavTab.home:
        break;
    }
  }

  void _showSignupDialog() {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '회원가입하시겠습니까?',
          style: TextStyle(
            color: c.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          '회원가입하면 활동 기록을 저장하고\n더 정확한 칼로리 계산이 가능해요.',
          style: TextStyle(
            color: c.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '나중에',
              style: TextStyle(
                color: c.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: Text(
              '회원가입하기',
              style: TextStyle(
                color: c.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final walk = ref.watch(walkSessionProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // App bar
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          context.wp(5), context.hp(1.5), context.wp(5), 0),
                      child: Row(
                        children: [
                          BrandLogo(size: context.wp(9)),
                          SizedBox(width: context.wp(2.5)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('좋은 아침이에요',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.textMuted,
                                      letterSpacing: 0.2)),
                              Text('오늘 어디까지 걸어볼까요?',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: c.text,
                                      letterSpacing: -0.2)),
                            ],
                          ),
                          const Spacer(),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.surface,
                                  border: Border.all(color: c.outline),
                                ),
                                child: Icon(Icons.notifications_rounded,
                                    size: 20, color: c.text),
                              ),
                              Positioned(
                                top: 8,
                                right: 9,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.secondary,
                                    border:
                                        Border.all(color: c.surface, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Mode toggle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(2), context.wp(5), 0),
                    child: SegmentedControl(
                      value: _mode,
                      options: const [
                        SegmentOption(value: 'A', label: '움직인 만큼 먹는다', icon: Icons.directions_walk_rounded),
                        SegmentOption(value: 'B', label: '먹기 위해 움직인다', icon: Icons.restaurant_rounded),
                      ],
                      onChanged: (v) => setState(() => _mode = v),
                    ),
                  ),
                ),

                // Hero CTA
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(1.8), context.wp(5), 0),
                    child: GestureDetector(
                      onTap: () => context.go(_mode == 'A' ? '/mode-a' : '/mode-b'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.primary, c.secondary],
                          ),
                          boxShadow: [
                            BoxShadow(color: c.primaryGlow, blurRadius: 30, offset: const Offset(0, 10)),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_mode == 'A' ? Icons.directions_walk_rounded : Icons.restaurant_rounded,
                                          size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('MODE $_mode',
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w800,
                                              color: Colors.white, letterSpacing: 0.2)),
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
                                      fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                                ),
                                SizedBox(height: context.hp(1.2)),
                                Row(
                                  children: [
                                    Text(
                                      _mode == 'A' ? '경로 입력하기' : '음식 고르기',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 18, color: Colors.white),
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

                // Quick stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(2.5), context.wp(5), 0),
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
                          value: (walk.distanceM / 1000).toStringAsFixed(1),
                          unit: 'km',
                          color: c.secondary,
                        ),
                      ],
                    ),
                  ),
                ),

                // Near restaurants
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(3), context.wp(5), 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
                            children: [
                              TextSpan(text: '광화문', style: TextStyle(color: c.primary)),
                              const TextSpan(text: ' 근처 관광 맛집'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/mode-b'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('더보기', style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w700)),
                              Icon(Icons.chevron_right_rounded, size: 16, color: c.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.hp(28),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(1.5), context.wp(5), context.hp(3)),
                      scrollDirection: Axis.horizontal,
                      itemCount: mockRestaurants.take(4).length,
                      separatorBuilder: (_, __) => SizedBox(width: context.wp(3)),
                      itemBuilder: (ctx, i) {
                        final r = mockRestaurants.elementAt(i);
                        return GestureDetector(
                          onTap: () => context.go('/restaurant/${r.id}'),
                          child: Container(
                            width: context.wp(41),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: c.outline),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FoodImageWidget(
                                    type: FoodImageWidget.fromString(r.imageType),
                                    height: context.hp(12)),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.name,
                                          style: TextStyle(
                                              color: c.text, fontWeight: FontWeight.w800,
                                              fontSize: 13, letterSpacing: -0.1),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(r.menu,
                                          style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.star_rounded, size: 11, color: c.accent),
                                          const SizedBox(width: 3),
                                          Text(r.rating.toString(),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.text)),
                                          Text(' · ', style: TextStyle(color: c.textFaint)),
                                          Text('${r.kcal} kcal',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Tourist routes section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(5), 0, context.wp(5), context.hp(1.5)),
                    child: Text('오늘의 관광 코스',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.2)),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(context.wp(5), 0, context.wp(5), context.hp(3)),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final r = mockRoutes.elementAt(i);
                        return Container(
                          margin: EdgeInsets.only(bottom: context.hp(1)),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                    r.type == '도보'
                                        ? Icons.hiking_rounded
                                        : Icons.directions_bike_rounded,
                                    size: 22, color: c.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name,
                                        style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('${r.distanceKm}km · ${r.durationMinutes}분 · 약 ${r.kcal} kcal',
                                        style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.textFaint),
                            ],
                          ),
                        );
                      },
                      childCount: mockRoutes.take(3).length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppBottomNav(activeTab: _activeTab, onChanged: _handleTabChange),
        ],
      ),
    ));
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
            Text(label,
                style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(value,
                      style: TextStyle(
                          color: c.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(unit, style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
