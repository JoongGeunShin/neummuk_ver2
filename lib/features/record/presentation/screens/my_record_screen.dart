import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../../../../core/widgets/weekly_chart.dart';
import '../../../record/domain/entities/badge_entity.dart';
import '../../../record/domain/entities/daily_record_entity.dart';
import '../../../walk/domain/entities/walk_session_entity.dart';
import '../../../walk/presentation/providers/walk_provider.dart';
import '../providers/record_provider.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _weekdayOf(String dateStr) {
  final date = DateTime.tryParse(dateStr);
  if (date == null) return '';
  return _weekdays[date.weekday - 1];
}

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
    final walk = ref.watch(walkSessionProvider);
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final weeklyAsync = ref.watch(weeklyDataProvider);
    final badgesAsync = ref.watch(badgesProvider);
    final weekRecordsAsync = ref.watch(weekRecordsProvider);

    return DoubleBackToExit(
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // Header — MY 페이지와 동일한 구조
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뒤로가기 + 타이틀 Row (MY 페이지 스타일)
                Padding(
                  padding: EdgeInsets.fromLTRB(context.wp(2), context.hp(1), context.wp(3), 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: c.text, size: 20),
                      ),
                      Text(
                        '나의 기록',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                            letterSpacing: -0.3),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // 통계 카드 + 탭바
                Padding(
                  padding: EdgeInsets.fromLTRB(context.wp(5), context.hp(1.5), context.wp(5), 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary cards — Firestore 주간 집계
                      summaryAsync.when(
                        loading: () => const _StatCardRow(
                            kcalText: '-', kmText: '-', daysText: '-'),
                        error: (_, __) => const _StatCardRow(
                            kcalText: '0', kmText: '0.0', daysText: '0'),
                        data: (s) => _StatCardRow(
                          kcalText: NumberFormat('#,###').format(s.kcal.round()),
                          kmText: s.km.toStringAsFixed(1),
                          daysText: s.days.toString(),
                        ),
                      ),

                      SizedBox(height: context.hp(2)),

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
              ],
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

                      // Activity tiles — Firestore 기록 + 실시간 walk 오버레이
                      weekRecordsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (records) =>
                            _WeekActivitySection(records: records, liveWalk: walk),
                      ),
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

        ],
      ),
    )); // DoubleBackToExit, Scaffold
  }
}

// ──────────────────────────────────────────────
// Summary card row
// ──────────────────────────────────────────────

class _StatCardRow extends StatelessWidget {
  const _StatCardRow({
    required this.kcalText,
    required this.kmText,
    required this.daysText,
  });
  final String kcalText;
  final String kmText;
  final String daysText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _StatCard(
          label: '이번 주 소모',
          value: kcalText,
          unit: 'kcal',
          color: c.primary,
          icon: Icons.local_fire_department_rounded,
          flex: 3,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: '총 거리',
          value: kmText,
          unit: 'km',
          color: c.secondary,
          icon: Icons.route_rounded,
          flex: 2,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: '활동 일수',
          value: daysText,
          unit: '일',
          color: c.accent,
          icon: Icons.calendar_today_rounded,
          flex: 2,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Activity section with real daily records
// ──────────────────────────────────────────────

class _WeekActivitySection extends StatelessWidget {
  const _WeekActivitySection({
    required this.records,
    required this.liveWalk,
  });
  final List<DailyRecordEntity> records;
  final WalkSessionEntity liveWalk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final firestoreToday = records.where((r) => r.date == today).firstOrNull;

    // 실시간 walk 데이터를 우선, 없으면 Firestore 저장값 사용
    final liveSteps = liveWalk.steps;
    final liveKcal = liveWalk.caloriesKcal;
    final liveKm = liveWalk.distanceM / 1000;
    final hasLive = liveSteps > 0;

    final todaySteps = hasLive ? liveSteps : (firestoreToday?.steps ?? 0);
    final todayKcal = hasLive ? liveKcal : (firestoreToday?.caloriesKcal ?? 0.0);
    final todayKm = hasLive ? liveKm : (firestoreToday?.distanceKm ?? 0.0);
    final hasTodayData = todaySteps > 0;

    final pastRecs = records
        .where((r) => r.date != today && r.steps > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 기록',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.2)),
        const SizedBox(height: 12),
        if (hasTodayData)
          _ActivityTile(
            icon: Icons.directions_walk_rounded,
            color: c.primary,
            title: '오늘 걷기',
            sub:
                '${NumberFormat('#,###').format(todaySteps)}걸음 · ${todayKm.toStringAsFixed(1)} km',
            kcal: todayKcal.round(),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: c.textFaint, size: 20),
                const SizedBox(width: 12),
                Text('아직 오늘 기록이 없어요',
                    style: TextStyle(color: c.textMuted, fontSize: 14)),
              ],
            ),
          ),
        if (pastRecs.isNotEmpty) ...[
          SizedBox(height: context.hp(3)),
          Text('이번 주 기록',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  letterSpacing: -0.2)),
          const SizedBox(height: 12),
          ...pastRecs.map((r) => _ActivityTile(
                icon: Icons.directions_walk_rounded,
                color: c.primary,
                title: '${_weekdayOf(r.date)}요일 걷기',
                sub:
                    '${NumberFormat('#,###').format(r.steps)}걸음 · ${r.distanceKm.toStringAsFixed(1)} km',
                kcal: r.caloriesKcal.round(),
              )),
        ],
        SizedBox(height: context.hp(2)),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Shared widgets
// ──────────────────────────────────────────────

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
  });
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final int kcal;

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
              Text('-$kcal',
                  style: TextStyle(
                      color: c.primary,
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
