import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/bottom_nav.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../../../../core/widgets/weekly_chart.dart';
import '../../../record/domain/entities/badge_entity.dart';
import '../providers/record_provider.dart';

class MyRecordScreen extends ConsumerStatefulWidget {
  const MyRecordScreen({super.key});

  @override
  ConsumerState<MyRecordScreen> createState() => _MyRecordScreenState();
}

class _MyRecordScreenState extends ConsumerState<MyRecordScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weeklyAsync = ref.watch(weeklyDataProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return DoubleBackToExit(
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.wp(5), 20, context.wp(5), 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('나의 기록',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('오늘도 잘 움직이고 있어요!',
                      style: TextStyle(
                          fontSize: 14,
                          color: c.textMuted,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: context.hp(2.5)),

                  // Summary cards
                  Row(
                    children: [
                      _StatCard(
                        label: '이번 주 소모',
                        value: '2,185',
                        unit: 'kcal',
                        color: c.primary,
                        icon: Icons.local_fire_department_rounded,
                        flex: 3,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: '총 거리',
                        value: '18.4',
                        unit: 'km',
                        color: c.secondary,
                        icon: Icons.route_rounded,
                        flex: 2,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: '활동 일수',
                        value: '5',
                        unit: '일',
                        color: c.accent,
                        icon: Icons.calendar_today_rounded,
                        flex: 2,
                      ),
                    ],
                  ),

                  SizedBox(height: context.hp(2.5)),

                  // Tab bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.outline),
                    ),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      indicatorPadding: const EdgeInsets.all(3),
                      labelColor: c.text,
                      unselectedLabelColor: c.textMuted,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: '주간 차트'),
                        Tab(text: '뱃지'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Weekly chart tab
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      context.wp(5), context.hp(2.5), context.wp(5), 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      weeklyAsync.when(
                        loading: () => SizedBox(
                          height: 180,
                          child: Center(
                              child: CircularProgressIndicator(color: c.primary)),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (weekly) => WeeklyChart(data: weekly),
                      ),
                      SizedBox(height: context.hp(3)),
                      Text('오늘의 기록',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 12),
                      _ActivityTile(
                        icon: Icons.directions_walk_rounded,
                        color: c.primary,
                        title: '광화문 → 남산',
                        sub: '3.2 km · 42분',
                        kcal: 235,
                      ),
                      _ActivityTile(
                        icon: Icons.restaurant_rounded,
                        color: c.secondary,
                        title: '명동교자 칼국수',
                        sub: '점심',
                        kcal: 520,
                        isFood: true,
                      ),
                      SizedBox(height: context.hp(3)),
                      Text('이번 주 기록',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 12),
                      _ActivityTile(
                        icon: Icons.directions_bike_rounded,
                        color: c.primary,
                        title: '한강공원 자전거',
                        sub: '12.4 km · 54분',
                        kcal: 520,
                      ),
                      _ActivityTile(
                        icon: Icons.directions_walk_rounded,
                        color: c.primary,
                        title: '북촌 한옥마을',
                        sub: '5.1 km · 68분',
                        kcal: 410,
                      ),
                      _ActivityTile(
                        icon: Icons.directions_bus_rounded,
                        color: c.textMuted,
                        title: '대중교통 이동',
                        sub: '1.2 km 환승',
                        kcal: 85,
                      ),
                      SizedBox(height: context.hp(2)),
                    ],
                  ),
                ),

                // Badges tab
                badgesAsync.when(
                  loading: () => Center(
                      child: CircularProgressIndicator(color: c.primary)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (badges) {
                    final earned = badges.where((b) => b.earned).toList();
                    final locked = badges.where((b) => !b.earned).toList();
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                          context.wp(5), context.hp(2.5), context.wp(5), 20),
                      children: [
                        Text('획득한 뱃지 ${earned.length}개',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: c.textMuted,
                                letterSpacing: 0.3)),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1),
                          itemCount: earned.length,
                          itemBuilder: (_, i) => _BadgeTile(
                              badge: earned[i], earned: true),
                        ),
                        SizedBox(height: context.hp(2.5)),
                        Text('잠긴 뱃지 ${locked.length}개',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: c.textMuted,
                                letterSpacing: 0.3)),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1),
                          itemCount: locked.length,
                          itemBuilder: (_, i) => _BadgeTile(
                              badge: locked[i], earned: false),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          AppBottomNav(
            activeTab: NavTab.record,
            onChanged: (_) {},
          ),
        ],
      ),
    ));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.flex,
  });
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5),
                children: [
                  TextSpan(text: value),
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                          fontSize: 10,
                          color: c.textMuted,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: c.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.kcal,
    this.isFood = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final int kcal;
  final bool isFood;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isFood ? '+' : '-'}$kcal',
                  style: TextStyle(
                      color: isFood ? c.kcalFood : c.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              Text('kcal',
                  style: TextStyle(
                      color: c.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});
  final BadgeEntity badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: earned ? c.surfaceAlt : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: earned ? c.primary.withValues(alpha: 0.3) : c.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1.0 : 0.3,
            child: Text(badge.icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 6),
          Text(badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: earned ? c.text : c.textFaint),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(badge.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: c.textMuted,
                    fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
