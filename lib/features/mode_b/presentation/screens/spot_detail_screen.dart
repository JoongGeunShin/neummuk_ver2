import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/context_ext.dart';
import '../../data/datasources/tour_api_detail_datasource.dart';
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
  late final PageController _pageCtrl;

  bool _detailLoading = true;
  String? _overview;
  String? _tel;
  String? _homepageUrl;
  String? _operatingInfo;
  List<String> _allImages = [];
  int _currentImagePage = 0;

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
    _pageCtrl = PageController();

    final spot = widget.spot;
    if (spot.imageUrl != null && spot.imageUrl!.isNotEmpty) {
      _allImages = [spot.imageUrl!];
    }
    _tel = spot.tel;

    _loadDetail();
  }

  @override
  void dispose() {
    _cartAnimCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final spot = widget.spot;
    final ds = TourApiDetailDatasource();

    try {
      if (spot.source == 'tour_api') {
        final parts = spot.id.split('_');
        if (parts.length >= 3) {
          final contentId = parts.last;
          final typeId = int.tryParse(parts[parts.length - 2]) ?? 12;
          final detail = await ds.fetchDetail(contentId, typeId);
          if (mounted && detail != null) {
            final merged = List<String>.from(_allImages);
            for (final img in detail.images) {
              if (!merged.contains(img)) merged.add(img);
            }
            setState(() {
              _overview = detail.overview;
              _tel = detail.tel ?? _tel;
              _homepageUrl = detail.homepageUrl;
              _operatingInfo = detail.operatingInfo;
              _allImages = merged;
            });
          }
        }
      } else {
        // 카카오: 이미지가 없으면 TourAPI 키워드 매칭 시도
        if (_allImages.isEmpty) {
          final img = await ds.findImageByKeyword(spot.name, spot.lat, spot.lng);
          if (mounted && img != null) {
            setState(() => _allImages = [img]);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  void _handleCart() {
    final cart = ref.read(cartProvider.notifier);
    final inCart = ref.read(cartProvider).any((s) => s.id == widget.spot.id);
    if (inCart) {
      cart.remove(widget.spot.id);
    } else {
      final added = cart.add(widget.spot);
      if (added) {
        _cartAnimCtrl.forward(from: 0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF333344),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            content: const Row(children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                '스팟은 최대 $kCartMaxSpots개까지 담을 수 있어요',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        );
      }
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callTel(String tel) async {
    final cleaned = tel.replaceAll(RegExp(r'\s'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spot = widget.spot;
    final inCart = ref.watch(cartProvider).any((s) => s.id == spot.id);

    final externalUrl =
        spot.source == 'kakao' ? spot.placeUrl : _homepageUrl;
    final externalLabel =
        spot.source == 'kakao' ? '지도에서 보기' : '공식 홈페이지';

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
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
              background: _ImageGallery(
                images: _allImages,
                loading: _detailLoading && _allImages.isEmpty,
                pageCtrl: _pageCtrl,
                currentPage: _currentImagePage,
                onPageChanged: (i) => setState(() => _currentImagePage = i),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 카테고리 칩
                if (spot.category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          spot.category!,
                          style: TextStyle(
                              fontSize: 11,
                              color: c.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                // 장소명
                Text(
                  spot.name,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.text),
                ),
                const SizedBox(height: 16),

                // 전화번호
                if (_tel != null) ...[
                  _TelRow(tel: _tel!, onTap: () => _callTel(_tel!)),
                  const SizedBox(height: 10),
                ],

                // 주소
                if (spot.address != null) ...[
                  _InfoRow(
                      icon: Icons.location_on_rounded, text: spot.address!),
                  const SizedBox(height: 10),
                ],

                // 거리
                if (spot.distanceFromUserM != null) ...[
                  _InfoRow(
                    icon: Icons.near_me_rounded,
                    text: spot.distanceFromUserM! < 1000
                        ? '${spot.distanceFromUserM}m 거리'
                        : '${(spot.distanceFromUserM! / 1000).toStringAsFixed(1)}km 거리',
                    color: c.primary,
                  ),
                  const SizedBox(height: 10),
                ],

                // 운영정보 카드
                if (_operatingInfo != null) ...[
                  const SizedBox(height: 4),
                  _OperatingInfoCard(info: _operatingInfo!),
                ],

                // 소개글
                if (_overview != null) ...[
                  const SizedBox(height: 16),
                  Divider(color: c.outline, height: 1),
                  const SizedBox(height: 16),
                  Text(
                    _overview!,
                    style: TextStyle(
                        fontSize: 14, color: c.textMuted, height: 1.75),
                  ),
                ],

                // 로딩 중 placeholder (이미지도 텍스트도 없을 때만)
                if (_detailLoading &&
                    _overview == null &&
                    _operatingInfo == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: _LoadingShimmer(),
                  ),
              ]),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 외부 링크 버튼 (카카오 스팟 or TourAPI homepage)
              if (externalUrl != null) ...[
                GestureDetector(
                  onTap: () => _openExternal(externalUrl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.outline, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 15, color: c.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          externalLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 장바구니 담기 버튼
              ScaleTransition(
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── 이미지 갤러리 ──────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.images,
    required this.loading,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<String> images;
  final bool loading;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (loading) {
      return Container(
        color: c.surfaceAlt,
        child: Center(
          child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
        ),
      );
    }

    if (images.isEmpty) {
      return Container(
        color: c.surfaceAlt,
        child: Center(
          child: Icon(Icons.landscape_rounded, size: 64, color: c.outline),
        ),
      );
    }

    Widget imageWidget;
    if (images.length == 1) {
      imageWidget = CachedNetworkImage(
        imageUrl: images.first,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          color: c.surfaceAlt,
          child:
              Center(child: Icon(Icons.landscape_rounded, size: 64, color: c.outline)),
        ),
      );
    } else {
      imageWidget = PageView.builder(
        controller: pageCtrl,
        onPageChanged: onPageChanged,
        itemCount: images.length,
        itemBuilder: (_, i) => CachedNetworkImage(
          imageUrl: images[i],
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: c.surfaceAlt,
            child: Center(
                child: Icon(Icons.landscape_rounded, size: 64, color: c.outline)),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        // 하단 그라데이션
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  c.bg.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        // 페이지 점 (복수 이미지)
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentPage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 전화번호 행 ───────────────────────────────────────────────────────────

class _TelRow extends StatelessWidget {
  const _TelRow({required this.tel, required this.onTap});
  final String tel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.phone_rounded, size: 16, color: c.primary),
          const SizedBox(width: 8),
          Text(
            tel,
            style: TextStyle(
                fontSize: 13, color: c.primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Icon(Icons.north_east_rounded, size: 11, color: c.primary),
        ],
      ),
    );
  }
}

// ── 정보 행 ──────────────────────────────────────────────────────────────

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
            style: TextStyle(
                fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── 운영정보 카드 ─────────────────────────────────────────────────────────

class _OperatingInfoCard extends StatelessWidget {
  const _OperatingInfoCard({required this.info});
  final String info;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        info,
        style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.7),
      ),
    );
  }
}

// ── 로딩 placeholder ──────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(c, double.infinity),
        const SizedBox(height: 8),
        _bar(c, 220),
        const SizedBox(height: 8),
        _bar(c, double.infinity),
        const SizedBox(height: 8),
        _bar(c, 160),
      ],
    );
  }

  Widget _bar(dynamic c, double width) => Container(
        height: 12,
        width: width,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
