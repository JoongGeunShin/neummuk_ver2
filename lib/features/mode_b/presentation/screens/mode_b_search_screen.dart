import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/double_back_to_exit.dart';
import '../providers/mode_b_provider.dart';

const _foodCats = [
  '전체',
  '치킨',
  '족발·보쌈',
  '돈까스·회·일식',
  '피자',
  '구이·고기',
  '야식',
  '양식',
  '중식',
  '아시안',
  '백반·죽·국수',
  '도시락',
  '분식',
  '카페·디저트',
  '패스트푸드',
];

class ModeBSearchScreen extends ConsumerWidget {
  const ModeBSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(foodSearchProvider);
    final notifier = ref.read(foodSearchProvider.notifier);

    return DoubleBackToExit(
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: Icon(Icons.arrow_back_rounded, color: c.text),
                      ),
                      Text('먹고 싶은 음식 고르기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: notifier.setQuery,
                            style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: '음식 이름 검색 (예: 삼겹살)',
                              hintStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _foodCats.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => AppChip(
                        label: _foodCats[i],
                        active: state.category == _foodCats[i],
                        onTap: () => notifier.setCategory(_foodCats[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Trending banner
          if (state.query.isEmpty && state.category == '전체')
            Padding(
              padding: EdgeInsets.fromLTRB(context.wp(4), 4, context.wp(4), 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.primary, c.secondary],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('🔥', style: TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('지금 떠오르는 메뉴',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white, height: 1)),
                          SizedBox(height: 2),
                          Text('오늘 점심엔 삼겹살 어때요?',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                    const Icon(Icons.trending_up_rounded, size: 22, color: Colors.white),
                  ],
                ),
              ),
            ),

          // Food count
          Padding(
            padding: EdgeInsets.fromLTRB(context.wp(4), 8, context.wp(4), 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${state.foods.length}개 메뉴',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: c.textMuted, letterSpacing: 0.4)),
            ),
          ),

          // Grid
          Expanded(
            child: state.isLoading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(context.wp(4), 0, context.wp(4), context.hp(3) + context.bottomPadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: context.screenWidth * 0.44 / 200,
                    ),
                    itemCount: state.foods.length,
                    itemBuilder: (ctx, i) {
                      final f = state.foods[i];
                      return GestureDetector(
                        onTap: () {
                          ref.read(selectedFoodProvider.notifier).set(f);
                          context.go('/mode-b/route');
                        },
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
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(f.emoji, style: TextStyle(fontSize: context.wp(7))),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(f.name,
                                  style: TextStyle(color: c.text, fontWeight: FontWeight.w800,
                                      fontSize: 14, letterSpacing: -0.1),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(f.category,
                                  style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 15),
                                      children: [
                                        TextSpan(text: '${f.kcal}'),
                                        TextSpan(text: ' kcal',
                                            style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: c.surfaceHi,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('🚶 ${f.walkMinutes}분',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.textMuted)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ));
  }
}
