import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/region_selector.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  static const int _totalSteps = 3;

  Future<void> _markDone() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_$uid', true);
  }

  Future<void> _next() async {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      await ref.read(userProfileProvider.notifier).saveProfile();
      await _markDone();
      if (mounted) context.go('/home'); // ignore: use_build_context_synchronously
    }
  }

  void _back() {
    if (_step == 0) {
      context.go('/login');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final buttonLabel = switch (_step) {
      0 => '다음',
      1 => '다음',
      _ => '내움먹 시작하기',
    };

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.wp(6)),
            child: Column(
              children: [
                // Progress bar + navigation
                Row(
                  children: [
                    GestureDetector(
                      onTap: _back,
                      child: Icon(Icons.arrow_back_rounded, color: c.text, size: 22),
                    ),
                    SizedBox(width: context.wp(4)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(height: 4, color: c.surfaceHi),
                            AnimatedFractionallySizedBox(
                              duration: const Duration(milliseconds: 320),
                              widthFactor: (_step + 1) / _totalSteps.toDouble(),
                              child: Container(height: 4, color: c.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: context.wp(4)),
                    GestureDetector(
                      onTap: () async {
                        await _markDone();
                        if (mounted) context.go('/home'); // ignore: use_build_context_synchronously
                      },
                      child: Text('건너뛰기',
                          style: TextStyle(
                              fontSize: context.wp(3.5),
                              fontWeight: FontWeight.w600,
                              color: c.textMuted)),
                    ),
                  ],
                ),
                SizedBox(height: context.hp(3.5)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (_step) {
                      0 => const _WeightStep(key: ValueKey(0)),
                      1 => const _RegionStep(key: ValueKey(1)),
                      _ => const _PrefsStep(key: ValueKey(2)),
                    },
                  ),
                ),
                AppButton(
                  label: buttonLabel,
                  onPressed: _next,
                  variant: ButtonVariant.primary,
                  iconRight: _step < _totalSteps - 1
                      ? Icons.arrow_forward_rounded
                      : null,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// ── Step 0: 신체 정보 ─────────────────────────────────────────────

class _WeightStep extends ConsumerWidget {
  const _WeightStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    final transports = [
      ('walk', '도보', Icons.directions_walk_rounded),
      ('bike', '자전거', Icons.directions_bike_rounded),
      ('transit', '대중교통', Icons.directions_bus_rounded),
    ];
    final sex = [
      ('male', '남성', Icons.male_rounded),
      ('female', '여성', Icons.female_rounded),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          '정확한 칼로리 계산을\n위해 알려주세요',
          style: TextStyle(
            fontSize: context.wp(6.5),
            fontWeight: FontWeight.w800,
            color: c.text,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: context.hp(1.2)),
        Text(
          '키, 체중과 평소 이동 수단을 알려주시면\n맞춤 칼로리·루트를 추천해 드려요.',
          style: TextStyle(fontSize: context.wp(3.5), color: c.textMuted, height: 1.5),
        ),
        SizedBox(height: context.hp(4.5)),
        // Height display
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                profile.heightCm.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: context.wp(18),
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text('cm',
                  style: TextStyle(
                      fontSize: context.wp(5.5),
                      fontWeight: FontWeight.w700,
                      color: c.textMuted)),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.primary,
            inactiveTrackColor: c.surfaceHi,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            trackHeight: 6,
          ),
          child: Slider(
            value: profile.heightCm,
            min: 100,
            max: 200,
            divisions: 1000,
            onChanged: (v) => notifier.setHeight(v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('100', style: TextStyle(fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
            Text('200', style: TextStyle(fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
          ],
        ),
        // Weight display
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                profile.weightKg.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: context.wp(18),
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text('kg',
                  style: TextStyle(
                      fontSize: context.wp(5.5),
                      fontWeight: FontWeight.w700,
                      color: c.textMuted)),
            ],
          ),
        ),
        SizedBox(height: context.hp(0.5)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.primary,
            inactiveTrackColor: c.surfaceHi,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            trackHeight: 6,
          ),
          child: Slider(
            value: profile.weightKg,
            min: 35,
            max: 120,
            divisions: 850,
            onChanged: (v) => notifier.setWeight(v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('35', style: TextStyle(fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
            Text('120', style: TextStyle(fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: context.hp(3.5)),
        Text('성별',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
        SizedBox(height: context.hp(1.5)),
        Row(
          children: sex.map((t) {
            final (id, label, icon) = t;
            final on = profile.sex == id;
            return Expanded(
              child: GestureDetector(
                onTap: () => notifier.setSex(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: context.hp(9),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: on ? c.primarySoft : c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: on ? c.primary : c.outline,
                        width: on ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: on ? c.primary : c.textMuted),
                      const SizedBox(height: 4),
                      Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: on ? c.primary : c.textMuted)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: context.hp(3.5)),
        Text('주로 이용하는 이동 수단',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
        SizedBox(height: context.hp(1.5)),
        Row(
          children: transports.map((t) {
            final (id, label, icon) = t;
            final on = profile.preferredTransport == id;
            return Expanded(
              child: GestureDetector(
                onTap: () => notifier.setTransport(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: context.hp(9),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: on ? c.primarySoft : c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: on ? c.primary : c.outline,
                        width: on ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: on ? c.primary : c.textMuted),
                      const SizedBox(height: 4),
                      Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: on ? c.primary : c.textMuted)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: context.hp(2)),
      ],
      ),
    );
  }
}

// ── Step 1: 선호 지역 ─────────────────────────────────────────────

class _RegionStep extends ConsumerWidget {
  const _RegionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '어떤 지역에\n관심이 있으신가요?',
            style: TextStyle(
              fontSize: context.wp(6.5),
              fontWeight: FontWeight.w800,
              color: c.text,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          SizedBox(height: context.hp(1.2)),
          Text(
            '선택한 지역의 관광지와 음식을 우선으로\n추천해 드려요. 여러 지역 선택 가능해요.',
            style: TextStyle(
                fontSize: context.wp(3.5), color: c.textMuted, height: 1.5),
          ),
          SizedBox(height: context.hp(3.5)),
          RegionSelector(
            value: profile.preferredRegions,
            onChanged: notifier.setRegions,
          ),
          SizedBox(height: context.hp(2)),
        ],
      ),
    );
  }
}

// ── Step 2: 선호 음식 ─────────────────────────────────────────────

class _PrefsStep extends ConsumerWidget {
  const _PrefsStep({super.key});

  static const _cats = [
    ('한식', '🍱'), ('분식', '🌶️'), ('중식', '🥟'),
    ('일식', '🍣'), ('양식', '🍝'), ('카페', '☕'),
    ('디저트', '🍰'), ('아시안', '🍛'), ('고기', '🥩'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 음식을\n좋아하시나요?',
          style: TextStyle(
            fontSize: context.wp(6.5),
            fontWeight: FontWeight.w800,
            color: c.text,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: context.hp(1.2)),
        Text(
          '취향 카테고리를 골라주시면 추천이\n더 정확해져요. (여러 개 선택 가능)',
          style: TextStyle(fontSize: context.wp(3.5), color: c.textMuted, height: 1.5),
        ),
        SizedBox(height: context.hp(4)),
        GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _cats.map((cat) {
              final (id, emoji) = cat;
              final on = profile.preferredCategories.contains(id);
              return GestureDetector(
                onTap: () => notifier.toggleCategory(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: on ? c.primarySoft : c.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: on ? c.primary : c.outline,
                        width: on ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: TextStyle(fontSize: context.wp(8))),
                      const SizedBox(height: 8),
                      Text(
                        id,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: on ? c.primary : c.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ),
        SizedBox(height: context.hp(2)),
      ],
      ),
    );
  }
}
