import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/calorie_bar.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/tiny_ring.dart';
import '../../../mode_a/data/repositories/mode_a_repository_impl.dart'
    show mockRestaurants;
import 'package:neummuk_ver2/core/theme/app_typography.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurantId});
  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = mockRestaurants.firstWhere(
      (r) => r.id == restaurantId,
      orElse: () => mockRestaurants.first,
    );

    const kcalBurn = 235;
    final ratio = r.kcal / kcalBurn;
    final matchPct = (100 - (1 - ratio).abs() * 100).clamp(0.0, 100.0);
    final matchColor = ratio < 1.1 && ratio > 0.9 ? c.success : c.kcalActivity;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    FoodImageWidget(
                      type: FoodImageWidget.fromString(r.imageType),
                      height: context.hp(32),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _FloatBtn(
                                icon: Icons.arrow_back_rounded,
                                onTap: () => context.pop(),
                              ),
                              Row(
                                children: [
                                  _FloatBtn(
                                    icon: Icons.favorite_border_rounded,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _FloatBtn(
                                    icon: Icons.share_rounded,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.wp(5),
                  context.hp(2.5),
                  context.wp(5),
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.primarySoft,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      r.category,
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: c.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r.name,
                                style: AppTypography.title.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: c.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    r.rating.toString(),
                                    style: AppTypography.label.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: c.text,
                                    ),
                                  ),
                                  Text(
                                    ' (${r.reviewCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')})',
                                    style: AppTypography.label.copyWith(
                                      color: c.textMuted,
                                    ),
                                  ),
                                  Text(
                                    ' · ${r.distanceLabel}',
                                    style: AppTypography.label.copyWith(
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        TinyRing(
                          pct: matchPct,
                          size: 56,
                          color: matchColor,
                          label: '${matchPct.round()}%',
                        ),
                      ],
                    ),

                    // Calorie panel
                    SizedBox(height: context.hp(2.2)),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 라우트와 칼로리 비교',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: c.textMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CalorieBar(kcalBurn: kcalBurn, kcalFood: r.kcal),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: matchPct > 80
                                  ? c.primarySoft
                                  : c.surfaceHi,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              matchPct > 80
                                  ? '오늘 소모한 ${kcalBurn}kcal과 거의 균형! 이 메뉴 추천 👍'
                                  : r.kcal > kcalBurn
                                  ? '이 메뉴는 +${r.kcal - kcalBurn}kcal. 10분 더 걸으면 0이에요.'
                                  : '소모량보다 적어요. 좀 더 든든한 메뉴는 어때요?',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: matchPct > 80 ? c.primary : c.text,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu list
                    SizedBox(height: context.hp(3)),
                    Text(
                      '대표 메뉴',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _MenuItem(
                          name: r.menu,
                          kcal: r.kcal,
                          price: '12,000원',
                          signature: true,
                        ),
                        _MenuItem(name: '추가 메뉴 A', kcal: 380, price: '9,000원'),
                        _MenuItem(
                          name: '추가 메뉴 B',
                          kcal: 520,
                          price: '14,000원',
                          isLast: true,
                        ),
                      ],
                    ),

                    // Reviews
                    SizedBox(height: context.hp(3)),
                    Text(
                      '관광객 후기',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ReviewCard(
                      who: '제주여행자',
                      when: '3일 전',
                      text: '광화문역에서 걸어오니 적당히 배고프고 칼로리 딱 맞아요. 면 강추!',
                      rating: 5,
                      isPrimary: true,
                    ),
                    _ReviewCard(
                      who: '오사카에서',
                      when: '1주 전',
                      text: '관광지 한복판인데 가성비도 좋고 줄도 빨라요. 다시 방문 의사 100%.',
                      rating: 4,
                      isPrimary: false,
                    ),
                    SizedBox(height: context.hp(12) + context.bottomPadding),
                  ]),
                ),
              ),
            ],
          ),

          // Sticky CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              // 그라디언트는 내비게이션 바 뒤까지 확장, 버튼은 SafeArea로 위로 올림
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.bg.withValues(alpha: 0),
                    c.bg.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.wp(5),
                    12,
                    context.wp(5),
                    context.hp(2),
                  ),
                  child: Row(
                    children: [
                      AppButton(
                        label: '길찾기',
                        onPressed: () {},
                        variant: ButtonVariant.secondary,
                        icon: Icons.map_rounded,
                        size: ButtonSize.lg,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: '예약하기',
                          onPressed: () {},
                          variant: ButtonVariant.primary,
                          icon: Icons.restaurant_menu_rounded,
                          fullWidth: true,
                        ),
                      ),
                    ],
                  ), // Row
                ), // Padding
              ), // SafeArea
            ), // Container
          ), // Positioned
        ], // Stack children
      ), // Stack (Scaffold body)
    );
  }
}

class _FloatBtn extends StatelessWidget {
  const _FloatBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.name,
    required this.kcal,
    required this.price,
    this.signature = false,
    this.isLast = false,
  });
  final String name;
  final int kcal;
  final String price;
  final bool signature;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTypography.bodyMute.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (signature) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SIGNATURE',
                          style: AppTypography.nano.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.onPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$kcal kcal',
                  style: AppTypography.tiny.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: AppTypography.bodyMute.copyWith(
              color: c.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.who,
    required this.when,
    required this.text,
    required this.rating,
    required this.isPrimary,
  });
  final String who;
  final String when;
  final String text;
  final int rating;
  final bool isPrimary;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrimary ? c.primary : c.secondary,
                ),
                child: Center(
                  child: Text(
                    who.characters.first,
                    style: AppTypography.label.copyWith(
                      color: c.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who,
                      style: AppTypography.label.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (k) => Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: k < rating ? c.accent : c.surfaceHi,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· $when',
                          style: AppTypography.micro.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.label.copyWith(
              color: c.text,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
