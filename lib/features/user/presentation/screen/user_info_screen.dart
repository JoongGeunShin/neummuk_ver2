import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/user_provider.dart';

class UserInfoScreen extends ConsumerWidget {
  const UserInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authStateProvider).valueOrNull;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(context.wp(2), context.hp(1), context.wp(5), 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.text, size: 20),
                  ),
                  Text('마이페이지',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.3)),
                ],
              ),
            ),

            Expanded(
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('프로필을 불러올 수 없어요',
                      style: TextStyle(color: c.textMuted, fontSize: 14)),
                ),
                data: (profile) => SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      context.wp(5), context.hp(2), context.wp(5), context.hp(3)),
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
                            child: Icon(Icons.person_rounded, color: c.primary, size: 32),
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

                      SizedBox(height: context.hp(5)),

                      // 로그아웃 버튼
                      GestureDetector(
                        onTap: () async {
                          await ref.read(authStateProvider.notifier).signOut();
                          if (context.mounted) context.go('/login');
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  color: Colors.red.shade400),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});
  final String label;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: 0.2));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.c,
  });
  final String label;
  final String value;
  final IconData icon;
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                    letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.2)),
          ],
        ),
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
      'transit' => ('대중교통', Icons.train_rounded),
      _ => ('도보', Icons.directions_walk_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(100),
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
