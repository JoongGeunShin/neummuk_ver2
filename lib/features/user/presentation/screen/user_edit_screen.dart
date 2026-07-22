import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/region_selector.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/domain/entities/user_profile_entity.dart';
import '../../presentation/providers/user_provider.dart';

class UserEditScreen extends ConsumerStatefulWidget {
  const UserEditScreen({super.key});

  @override
  ConsumerState<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends ConsumerState<UserEditScreen> {
  bool _initialized = false;
  bool _saving = false;

  double _heightCm = 170.0;
  double _weightKg = 65.0;
  int _age = 30;
  String _sex = 'male';
  String _transport = 'walk';
  List<String> _categories = ['한식'];
  List<String> _regions = ['전체'];

  static const _transports = [
    ('walk', '도보', Icons.directions_walk_rounded),
    ('bike', '자전거', Icons.directions_bike_rounded),
    ('transit', '대중교통', Icons.directions_bus_rounded),
  ];
  static const _sexOptions = [
    ('male', '남성', Icons.male_rounded),
    ('female', '여성', Icons.female_rounded),
  ];
  static const _cats = [
    ('한식', '🍱'), ('분식', '🌶️'), ('중식', '🥟'),
    ('일식', '🍣'), ('양식', '🍝'), ('카페', '☕'),
    ('디저트', '🍰'), ('아시안', '🍛'), ('고기', '🥩'),
  ];

  void _initFrom(UserProfileEntity? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _heightCm = profile.heightCm;
    _weightKg = profile.weightKg;
    _age = profile.age;
    _sex = profile.sex;
    _transport = profile.preferredTransport;
    _categories = List<String>.from(profile.preferredCategories);
    _regions = List<String>.from(profile.preferredRegions);
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).saveUserProfile(
            user,
            UserProfileEntity(
              heightCm: _heightCm,
              weightKg: _weightKg,
              age: _age,
              sex: _sex,
              preferredTransport: _transport,
              preferredCategories: List<String>.from(_categories),
              preferredRegions: List<String>.from(_regions),
            ),
          );
      ref.invalidate(userProfileProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Text('불러올 수 없어요', style: TextStyle(color: c.textMuted)),
        ),
      ),
      data: (profile) {
        _initFrom(profile);
        return _buildForm(context, c);
      },
    );
  }

  Widget _buildForm(BuildContext context, dynamic c) {
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
                  Text(
                    '프로필 수정',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.3),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    context.wp(5), context.hp(2), context.wp(5), context.hp(2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 신체 정보 ──────────────────────────────
                    _SectionLabel(label: '신체 정보', c: c),
                    SizedBox(height: context.hp(2)),

                    // Height
                    _SliderRow(
                      label: '키',
                      value: _heightCm,
                      unit: 'cm',
                      min: 100,
                      max: 200,
                      divisions: 1000,
                      c: c,
                      onChanged: (v) => setState(() => _heightCm = v),
                    ),
                    SizedBox(height: context.hp(2)),

                    // Weight
                    _SliderRow(
                      label: '체중',
                      value: _weightKg,
                      unit: 'kg',
                      min: 35,
                      max: 120,
                      divisions: 850,
                      c: c,
                      onChanged: (v) => setState(() => _weightKg = v),
                    ),
                    SizedBox(height: context.hp(2)),

                    // Age
                    _SliderRow(
                      label: '나이',
                      value: _age.toDouble(),
                      unit: '세',
                      min: 14,
                      max: 100,
                      divisions: 86,
                      decimals: 0,
                      c: c,
                      onChanged: (v) => setState(() => _age = v.round()),
                    ),
                    SizedBox(height: context.hp(2.5)),

                    // Sex
                    Text('성별',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                    SizedBox(height: context.hp(1)),
                    Row(
                      children: _sexOptions.map((t) {
                        final (id, label, icon) = t;
                        final on = _sex == id;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _sex = id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: context.hp(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: on ? c.primarySoft : c.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: on ? c.primary : c.outline,
                                    width: on ? 2 : 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon,
                                      size: 20, color: on ? c.primary : c.textMuted),
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

                    SizedBox(height: context.hp(3)),

                    // ── 이동수단 ────────────────────────────────
                    _SectionLabel(label: '선호 이동수단', c: c),
                    SizedBox(height: context.hp(1)),
                    Row(
                      children: _transports.map((t) {
                        final (id, label, icon) = t;
                        final on = _transport == id;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _transport = id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: context.hp(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: on ? c.primarySoft : c.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: on ? c.primary : c.outline,
                                    width: on ? 2 : 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon,
                                      size: 20, color: on ? c.primary : c.textMuted),
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

                    SizedBox(height: context.hp(3)),

                    // ── 선호 지역 ───────────────────────────────
                    _SectionLabel(label: '선호 지역', c: c),
                    SizedBox(height: context.hp(1)),
                    RegionSelector(
                      value: _regions,
                      onChanged: (v) => setState(() => _regions = v),
                    ),

                    SizedBox(height: context.hp(3)),

                    // ── 음식 카테고리 ────────────────────────────
                    _SectionLabel(label: '선호 음식 카테고리', c: c),
                    SizedBox(height: context.hp(1)),
                    GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _cats.map((cat) {
                        final (id, emoji) = cat;
                        final on = _categories.contains(id);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (on) {
                              _categories.remove(id);
                            } else {
                              _categories.add(id);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
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
                                Text(emoji,
                                    style: TextStyle(fontSize: context.wp(7))),
                                const SizedBox(height: 6),
                                Text(
                                  id,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: on ? c.primary : c.text,
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
              ),
            ),

            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  context.wp(5), 0, context.wp(5), context.hp(3)),
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: '저장하기',
                      onPressed: _save,
                      variant: ButtonVariant.primary,
                      fullWidth: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.c});
  final String label;
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.2),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.c,
    required this.onChanged,
    this.decimals = 1,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final dynamic c;
  final ValueChanged<double> onChanged;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(decimals)} $unit',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                  letterSpacing: -0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.primary,
            inactiveTrackColor: c.surfaceHi,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            trackHeight: 5,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${min.toInt()}',
                style: TextStyle(
                    fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
            Text('${max.toInt()}',
                style: TextStyle(
                    fontSize: 11, color: c.textFaint, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
