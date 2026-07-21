import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_nav_provider.dart';
import '../../../walk/presentation/providers/walk_provider.dart';
import '../providers/user_provider.dart';

class UserInfoScreen extends ConsumerStatefulWidget {
  const UserInfoScreen({super.key});

  @override
  ConsumerState<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends ConsumerState<UserInfoScreen> {
  bool _deleting = false;

  List<Widget> _buildRegionChips(List<String> regions, dynamic c) {
    if (regions.contains('전체')) {
      return [_CategoryChip(label: '전체', c: c)];
    }
    return regions.map((r) {
      final label = r.contains('/') ? r.replaceAll('/', ' ') : r;
      return _CategoryChip(label: label, c: c);
    }).toList();
  }

  Future<void> _clearLocalSessionCache() async {
    await ref.read(walkSessionProvider.notifier).resetForLogout();
    await ref.read(modeAProvider.notifier).clearAll();
    await ref.read(modeBNavProvider.notifier).stop();
  }

  Future<void> _signOut() async {
    await _clearLocalSessionCache();
    await ref.read(authStateProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _showDeleteDialog() async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '회원 탈퇴',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
        ),
        content: Text(
          '정말 탈퇴하시겠어요?\n모든 활동 기록이 삭제되며\n복구할 수 없어요.',
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text('취소',
                style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: Text('탈퇴',
                style: TextStyle(
                    color: Colors.red.shade400, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _clearLocalSessionCache();
      await ref.read(authStateProvider.notifier).deleteAccount();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(authStateProvider).valueOrNull;
    final profileAsync = ref.watch(userProfileProvider);

    return DoubleBackToExit(
      child: Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(context.wp(2), context.hp(1), context.wp(3), 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.text, size: 20),
                  ),
                  Text(
                    '마이페이지',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/user/edit'),
                    icon: Icon(Icons.edit_outlined, color: c.textMuted, size: 20),
                    tooltip: '프로필 수정',
                  ),
                ],
              ),
            ),

            // Scrollable profile content
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('프로필을 불러올 수 없어요',
                      style: TextStyle(color: c.textMuted, fontSize: 14)),
                ),
                data: (profile) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      context.wp(5), context.hp(2), context.wp(5), context.hp(2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name/email
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.primarySoft,
                            ),
                            child: Icon(Icons.person_rounded,
                                color: c.primary, size: 32),
                          ),
                          SizedBox(width: context.wp(4)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? '사용자',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: c.text,
                                      letterSpacing: -0.4),
                                ),
                                if (user?.email.isNotEmpty == true)
                                  Text(
                                    user!.email,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c.textMuted,
                                        fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: context.hp(3)),

                      // 신체 정보
                      _SectionLabel(label: '신체 정보', colors: c),
                      SizedBox(height: context.hp(1)),
                      Row(
                        children: [
                          _StatCard(
                            label: '키',
                            value: profile != null
                                ? '${profile.heightCm.toStringAsFixed(1)} cm'
                                : '-',
                            icon: Icons.height_rounded,
                            c: c,
                          ),
                          SizedBox(width: context.wp(2.5)),
                          _StatCard(
                            label: '체중',
                            value: profile != null
                                ? '${profile.weightKg.toStringAsFixed(1)} kg'
                                : '-',
                            icon: Icons.monitor_weight_outlined,
                            c: c,
                          ),
                          SizedBox(width: context.wp(2.5)),
                          _StatCard(
                            label: '성별',
                            value: profile != null
                                ? (profile.sex == 'male' ? '남성' : '여성')
                                : '-',
                            icon: Icons.wc_rounded,
                            c: c,
                          ),
                        ],
                      ),

                      SizedBox(height: context.hp(3)),

                      // 이동 선호
                      _SectionLabel(label: '선호 이동수단', colors: c),
                      SizedBox(height: context.hp(1)),
                      if (profile != null)
                        _TransportChip(transport: profile.preferredTransport, c: c)
                      else
                        Text('-', style: TextStyle(color: c.textMuted)),

                      SizedBox(height: context.hp(3)),

                      // 선호 지역
                      _SectionLabel(label: '선호 지역', colors: c),
                      SizedBox(height: context.hp(1)),
                      if (profile != null && profile.preferredRegions.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildRegionChips(profile.preferredRegions, c),
                        )
                      else
                        Text('전체', style: TextStyle(color: c.textMuted)),

                      SizedBox(height: context.hp(3)),

                      // 음식 선호
                      _SectionLabel(label: '선호 음식 카테고리', colors: c),
                      SizedBox(height: context.hp(1)),
                      if (profile != null && profile.preferredCategories.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.preferredCategories
                              .map((cat) => _CategoryChip(label: cat, c: c))
                              .toList(),
                        )
                      else
                        Text('-', style: TextStyle(color: c.textMuted)),

                      SizedBox(height: context.hp(3)),

                      // 설정
                      _SectionLabel(label: '설정', colors: c),
                      SizedBox(height: context.hp(1)),
                      const _TrackingToggleTile(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom actions
            Padding(
              padding: EdgeInsets.fromLTRB(
                  context.wp(5), 0, context.wp(5), context.hp(3)),
              child: Column(
                children: [
                  // 로그아웃
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.outline),
                      ),
                      child: Center(
                        child: Text(
                          '로그아웃',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 회원탈퇴
                  GestureDetector(
                    onTap: _deleting ? null : _showDeleteDialog,
                    child: _deleting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '회원탈퇴',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textFaint,
                                decoration: TextDecoration.underline,
                                decorationColor: c.textFaint),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});
  final String label;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: colors.text),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.c});
  final String label;
  final String value;
  final IconData icon;
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _TrackingToggleTile extends ConsumerWidget {
  const _TrackingToggleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final trackingEnabled = ref.watch(walkSessionProvider).trackingEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk_rounded, size: 20, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('백그라운드 활동 추적',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 2),
                Text(
                  '앱을 꺼도 걸음 수·칼로리를 계속 추적해요.\n끄면 배터리 소모를 줄일 수 있어요.',
                  style: TextStyle(
                      fontSize: 11.5, color: c.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          Switch(
            value: trackingEnabled,
            activeThumbColor: c.primary,
            onChanged: (v) =>
                ref.read(walkSessionProvider.notifier).setTrackingEnabled(v),
          ),
        ],
      ),
    );
  }
}

class _TransportChip extends StatelessWidget {
  const _TransportChip({required this.transport, required this.c});
  final String transport;
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (transport) {
      'bike' => ('자전거', Icons.directions_bike_rounded),
      'transit' => ('대중교통', Icons.directions_bus_rounded),
      _ => ('도보', Icons.directions_walk_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.primary)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.c});
  final String label;
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outline),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.text)),
    );
  }
}
