import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_chip.dart';
import '../providers/mode_a_provider.dart';

class ModeAInputScreen extends ConsumerStatefulWidget {
  const ModeAInputScreen({super.key});

  @override
  ConsumerState<ModeAInputScreen> createState() => _ModeAInputScreenState();
}

class _ModeAInputScreenState extends ConsumerState<ModeAInputScreen> {
  String _focused = 'to';
  final _toCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();

  static const _recents = [
    ('남산서울타워', '서울 용산구 남산공원길'),
    ('경복궁', '서울 종로구 사직로'),
    ('명동성당', '서울 중구 명동길'),
    ('북촌한옥마을', '서울 종로구 계동길'),
  ];
  static const _recentSearches = ['남산서울타워', '성수동 카페거리', '한강공원 뚝섬'];

  @override
  void initState() {
    super.initState();
    final state = ref.read(modeAProvider);
    _fromCtrl.text = state.from;
    _toCtrl.text = state.to;
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _fromCtrl.dispose();
    super.dispose();
  }

  void _selectDest(String name) {
    ref.read(modeAProvider.notifier).setTo(name);
    _toCtrl.text = name;
    ref.read(modeAProvider.notifier).search();
    context.go('/mode-a/result');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final to = ref.watch(modeAProvider).to;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // Search header
          SafeArea(
            bottom: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
              color: c.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: Icon(Icons.arrow_back_rounded, color: c.text),
                      ),
                      Expanded(
                        child: Text('경로 검색',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.swap_vert_rounded, color: c.textMuted),
                      ),
                    ],
                  ),
                  SizedBox(height: context.hp(1.8)),
                  Container(
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.outline),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        _SearchField(
                          dot: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.pinUser,
                              border: Border.all(color: c.text, width: 2),
                            ),
                          ),
                          controller: _fromCtrl,
                          placeholder: '출발지',
                          focused: _focused == 'from',
                          onFocus: () => setState(() => _focused = 'from'),
                          onChanged: (v) => ref.read(modeAProvider.notifier).setFrom(v),
                        ),
                        Divider(color: c.outline, height: 1, indent: 24),
                        _SearchField(
                          dot: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: c.secondary),
                            child: const Icon(Icons.place_rounded, size: 10, color: Colors.white),
                          ),
                          controller: _toCtrl,
                          placeholder: '어디로 갈까요?',
                          focused: _focused == 'to',
                          onFocus: () => setState(() => _focused = 'to'),
                          onChanged: (v) {
                            ref.read(modeAProvider.notifier).setTo(v);
                            setState(() {});
                          },
                          autofocus: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(8, context.hp(2.5), 8, context.hp(2.5) + context.bottomPadding),
              children: [
                if (to.isEmpty) ...[
                  _SectionLabel(label: '최근 검색'),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentSearches
                          .map((s) => AppChip(
                                label: s,
                                icon: Icons.history_rounded,
                                onTap: () => _selectDest(s),
                              ))
                          .toList(),
                    ),
                  ),
                  _SectionLabel(label: '관광지 추천'),
                ],
                ..._recents
                    .where((r) => to.isEmpty || r.$1.contains(to))
                    .map((r) => _PlaceRow(
                          name: r.$1,
                          sub: r.$2,
                          onTap: () => _selectDest(r.$1),
                          secondary: c.secondary,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.dot,
    required this.controller,
    required this.placeholder,
    required this.focused,
    required this.onFocus,
    required this.onChanged,
    this.autofocus = false,
  });

  final Widget dot;
  final TextEditingController controller;
  final String placeholder;
  final bool focused;
  final VoidCallback onFocus;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: dot)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onTap: onFocus,
              onChanged: onChanged,
              style: TextStyle(
                  color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: Icon(Icons.cancel_rounded, size: 18, color: c.textFaint),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: c.textMuted, letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.name,
    required this.sub,
    required this.onTap,
    required this.secondary,
  });
  final String name;
  final String sub;
  final VoidCallback onTap;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.photo_camera_rounded, color: secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_outward_rounded, size: 20, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
