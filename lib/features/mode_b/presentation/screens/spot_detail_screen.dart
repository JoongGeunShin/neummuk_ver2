import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/context_ext.dart';
import '../../domain/entities/spot_entity.dart';
import '../providers/cart_provider.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({super.key, required this.spot});
  final SpotEntity spot;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cartAnimCtrl;
  late final Animation<double> _cartScale;

  @override
  void initState() {
    super.initState();
    _cartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _cartAnimCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _cartAnimCtrl.dispose();
    super.dispose();
  }

  void _handleCart() {
    final cart = ref.read(cartProvider.notifier);
    final inCart = ref.read(cartProvider).any((s) => s.id == widget.spot.id);
    if (inCart) {
      cart.remove(widget.spot.id);
    } else {
      cart.add(widget.spot);
      _cartAnimCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spot = widget.spot;
    final inCart = ref.watch(cartProvider).any((s) => s.id == spot.id);

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          // 상단 이미지 + 뒤로가기
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded, color: c.text, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _SpotImageHeader(imageUrl: spot.imageUrl),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 이름 + 카테고리
                if (spot.category != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      spot.category!,
                      style: TextStyle(
                          fontSize: 11, color: c.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                Text(
                  spot.name,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 16),

                // 정보 행
                _InfoRow(icon: Icons.category_rounded, text: spot.type),
                if (spot.address != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.location_on_rounded, text: spot.address!),
                ],
                if (spot.distanceFromUserM != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.near_me_rounded,
                    text: spot.distanceFromUserM! < 1000
                        ? '${spot.distanceFromUserM}m 거리'
                        : '${(spot.distanceFromUserM! / 1000).toStringAsFixed(1)}km 거리',
                    color: c.primary,
                  ),
                ],
                if (spot.source == 'kakao') ...[
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.place_rounded, text: '카카오 장소 정보'),
                ] else ...[
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.travel_explore_rounded, text: '한국관광공사 데이터'),
                ],
              ]),
            ),
          ),
        ],
      ),

      // 하단 담기 버튼
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: ScaleTransition(
            scale: _cartScale,
            child: GestureDetector(
              onTap: _handleCart,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: inCart ? c.surfaceAlt : c.primary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: inCart ? c.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        inCart
                            ? Icons.shopping_cart_checkout_rounded
                            : Icons.add_shopping_cart_rounded,
                        key: ValueKey(inCart),
                        size: 20,
                        color: inCart ? c.primary : c.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        inCart ? '장바구니에서 빼기' : '코스 장바구니에 담기',
                        key: ValueKey(inCart),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: inCart ? c.primary : c.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 이미지 헤더 ──────────────────────────────────────────────────

class _SpotImageHeader extends StatelessWidget {
  const _SpotImageHeader({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: c.surfaceAlt,
        child: Center(
          child: Icon(Icons.landscape_rounded, size: 64, color: c.outline),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: c.surfaceAlt,
        child: Center(child: Icon(Icons.landscape_rounded, size: 64, color: c.outline)),
      ),
    );
  }
}

// ── 정보 행 ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textColor = color ?? c.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
