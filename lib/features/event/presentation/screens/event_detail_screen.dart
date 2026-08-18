import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../domain/entities/event_detail_entity.dart';
import '../providers/event_detail_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({
    super.key,
    required this.contentId,
    this.fallbackImageUrl,
  });
  final String contentId;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      eventDetailProvider(contentId, fallbackImageUrl: fallbackImageUrl),
    );
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => _LoadingView(),
        error: (_, __) => _ErrorView(),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

// ── 로딩 ────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Container(color: c.surfaceAlt, height: context.hp(40)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _FloatBtn(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
          ),
        ),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FloatBtn(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
            ),
          ),
          const Spacer(),
          Icon(Icons.error_outline_rounded, size: 48, color: c.textFaint),
          const SizedBox(height: 12),
          Text('정보를 불러오지 못했습니다',
              style: TextStyle(color: c.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── 본문 ────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final EventDetailEntity detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hasLink = detail.effectiveHomepage?.isNotEmpty == true;
    final hasDest = detail.lat != null && detail.lng != null;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // 헤더 이미지
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  _HeaderImage(imageUrl: detail.effectiveImageUrl, height: context.hp(36)),
                  // 상단 버튼 오버레이
                  Positioned(
                    top: 0, left: 0, right: 0,
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
                            if (detail.tel?.isNotEmpty == true)
                              _FloatBtn(
                                icon: Icons.phone_rounded,
                                onTap: () => _copyToClipboard(context, detail.tel!),
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
                  context.wp(5), context.hp(2.5), context.wp(5), 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 제목 + 등급 배지
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          detail.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (detail.festivalgrade?.isNotEmpty == true) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            detail.festivalgrade!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 날짜 + 장소
                  if (detail.dateRangeLabel.isNotEmpty)
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      text: detail.dateRangeLabel,
                      color: c.primary,
                    ),
                  if (detail.eventplace?.isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.place_rounded,
                      text: detail.eventplace!,
                    ),
                  if (detail.addr?.isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.map_outlined,
                      text: detail.addr!,
                    ),
                  if (detail.tel?.isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      text: detail.tel!,
                      onTap: () => _copyToClipboard(context, detail.tel!),
                    ),

                  // 행사 안내 카드
                  if (_hasAny([
                    detail.playtime,
                    detail.spendtime,
                    detail.agelimit,
                  ])) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('행사 안내'),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      if (detail.playtime?.isNotEmpty == true)
                        _InfoCardRow(label: '공연시간', value: detail.playtime!),
                      if (detail.spendtime?.isNotEmpty == true)
                        _InfoCardRow(label: '관람소요시간', value: detail.spendtime!),
                      if (detail.agelimit?.isNotEmpty == true)
                        _InfoCardRow(label: '관람가능연령', value: detail.agelimit!),
                    ]),
                  ],

                  // 프로그램
                  if (detail.program?.isNotEmpty == true) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('행사 프로그램'),
                    const SizedBox(height: 10),
                    _TextBlock(text: detail.program!),
                  ],

                  // 위치 안내
                  if (detail.placeinfo?.isNotEmpty == true) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('위치 안내'),
                    const SizedBox(height: 10),
                    _TextBlock(text: detail.placeinfo!),
                  ],

                  // 예매 / 할인
                  if (_hasAny([detail.bookingplace, detail.discountinfo])) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('예매 · 할인'),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      if (detail.bookingplace?.isNotEmpty == true)
                        _InfoCardRow(label: '예매처', value: detail.bookingplace!),
                      if (detail.discountinfo?.isNotEmpty == true)
                        _InfoCardRow(label: '할인정보', value: detail.discountinfo!),
                    ]),
                  ],

                  // 홈페이지 링크
                  if (detail.effectiveHomepage?.isNotEmpty == true) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('홈페이지'),
                    const SizedBox(height: 10),
                    _LinkBlock(
                      url: detail.effectiveHomepage!,
                      onTap: () =>
                          _copyToClipboard(context, detail.effectiveHomepage!),
                    ),
                  ],

                  // 개요
                  if (detail.overview?.isNotEmpty == true) ...[
                    SizedBox(height: context.hp(2.5)),
                    _SectionTitle('행사 소개'),
                    const SizedBox(height: 10),
                    _TextBlock(text: detail.overview!),
                  ],

                  SizedBox(
                      height: context.hp((hasDest ? 7 : 0) + (hasLink ? 12 : 5)) +
                          context.bottomPadding),
                ]),
              ),
            ),
          ],
        ),

        // 하단 CTA — 도착지 설정 + 홈페이지
        if (hasDest || hasLink)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomCta(
              children: [
                if (hasDest)
                  _SetDestCta(
                    onTap: () {
                      final notifier = ref.read(modeAProvider.notifier);
                      notifier.setDestCoords(
                          detail.lat!, detail.lng!, detail.title);
                      ref.read(mapModeProvider.notifier).set(MapMode.modeA);
                      if (ref.read(modeAProvider).originLat != null) {
                        notifier.search();
                      }
                      context.push('/map');
                    },
                  ),
                if (hasLink)
                  _HomepageCta(
                    url: detail.effectiveHomepage!,
                    onTap: () =>
                        _copyToClipboard(context, detail.effectiveHomepage!),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _hasAny(List<String?> vals) => vals.any((v) => v?.isNotEmpty == true);

  static void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('클립보드에 복사했습니다'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── 서브 위젯들 ────────────────────────────────────────────

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.imageUrl, required this.height});
  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (imageUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(c, height),
        errorWidget: (_, __, ___) => _placeholder(c, height),
      );
    }
    return _placeholder(c, height);
  }

  Widget _placeholder(dynamic c, double h) => Container(
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.primarySoft, c.secondarySoft],
          ),
        ),
        child: Icon(Icons.festival_rounded, size: 64, color: c.primary),
      );
}

class _FloatBtn extends StatelessWidget {
  const _FloatBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = color ?? c.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color ?? c.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: context.colors.text,
          letterSpacing: -0.2,
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoCardRow extends StatelessWidget {
  const _InfoCardRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c.text,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
    );
  }
}

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 16, color: c.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: TextStyle(
                  color: c.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: c.primary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
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
              context.wp(5), 12, context.wp(5), context.hp(2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetDestCta extends StatelessWidget {
  const _SetDestCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.place_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              '모드A 도착지로 설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomepageCta extends StatelessWidget {
  const _HomepageCta({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_browser_rounded, color: c.text, size: 18),
            const SizedBox(width: 8),
            Text(
              '홈페이지 주소 복사',
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
