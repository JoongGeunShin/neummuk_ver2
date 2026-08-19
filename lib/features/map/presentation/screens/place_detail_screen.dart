import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../../core/widgets/map_widgets.dart';
import '../../../mode_a/domain/entities/restaurant_entity.dart';
import '../../../mode_a/domain/entities/route_result_entity.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../mode_b/data/datasources/tour_api_detail_datasource.dart';
import '../../../mode_b/domain/entities/tourist_route_entity.dart';
import '../../../mode_b/presentation/providers/mode_b_provider.dart';
import '../../domain/entities/place_entity.dart';
import '../providers/map_mode_provider.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── 통합 상세 데이터 모델 (PlaceEntity / RestaurantEntity → 정규화)
// ════════════════════════════════════════════════════════════════════════════

class _Detail {
  _Detail({
    required this.name,
    this.category,
    this.address,
    this.phone,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.source,
    this.kcalEstimate,
    this.targetKcal,
    this.distanceM,
    this.walkMinutes,
    this.menu,
    this.tags = const [],
    this.imageType = 'generic',
    this.rating = 0.0,
    this.isRestaurant = false,
  });

  factory _Detail.fromPlace(PlaceEntity p) => _Detail(
    name: p.name,
    category: _trimCategory(p.category),
    address: p.address,
    phone: p.phone,
    imageUrl: p.imageUrl,
    latitude: p.latitude,
    longitude: p.longitude,
    source: p.source,
    kcalEstimate: p.kcalEstimate,
    targetKcal: p.targetKcal,
    menu: p.menu,
  );

  factory _Detail.fromTouristRoute(TouristRouteEntity r) => _Detail(
    name: r.name,
    category: r.region != null ? '${r.type} · ${r.region}' : r.type,
    address: r.region,
    imageUrl: r.imageUrls.isNotEmpty ? r.imageUrls.first : null,
    latitude: r.startLat ?? 0,
    longitude: r.startLng ?? 0,
    source: r.id.startsWith('tour_') ? PlaceSource.tourApi : PlaceSource.both,
    kcalEstimate: r.kcal > 0 ? r.kcal : null,
    distanceM: r.distanceKm > 0 ? (r.distanceKm * 1000).round() : null,
    walkMinutes: r.durationMinutes > 0 ? r.durationMinutes : null,
    menu: r.type,
    tags: r.tags,
  );

  factory _Detail.fromRestaurant(RestaurantEntity r) => _Detail(
    name: r.name,
    category: r.category,
    address: r.address,
    phone: r.tel,
    latitude: r.latitude,
    longitude: r.longitude,
    kcalEstimate: r.kcal,
    distanceM: r.distanceM,
    walkMinutes: r.walkMinutes,
    menu: r.menu,
    tags: r.tags,
    imageType: r.imageType,
    rating: r.rating,
    isRestaurant: true,
  );

  final String name;
  final String? category;
  final String? address;
  final String? phone;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final PlaceSource? source;
  final int? kcalEstimate;

  /// 비교 기준 칼로리(오늘 소모/burn 등) — kcalEstimate와 짝을 이룰 때만 의미 있음
  final int? targetKcal;
  final int? distanceM;
  final int? walkMinutes;
  final String? menu;
  final List<String> tags;
  final String imageType;
  final double rating;
  final bool isRestaurant;

  static String? _trimCategory(String? cat) {
    if (cat == null || cat.isEmpty) return null;
    final parts = cat
        .split('>')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.last : cat;
  }

  bool get showInfoRow =>
      isRestaurant || kcalEstimate != null || distanceM != null;

  int? get kcalDiff => (kcalEstimate != null && targetKcal != null)
      ? kcalEstimate! - targetKcal!
      : null;

  (String, Color) get badge {
    if (isRestaurant) {
      return (category ?? '음식점', const Color(0xFF03C75A));
    }
    return switch (source ?? PlaceSource.kakaoLocal) {
      PlaceSource.tourApi => ('장소', const Color(0xFFFF5722)),
      PlaceSource.kakaoLocal => ('장소', const Color(0xFF1E88E5)),
      PlaceSource.both => ('⭐ 추천', const Color(0xFF03C75A)),
    };
  }

  String? get distanceLabel => distanceM == null
      ? null
      : distanceM! < 1000
      ? '${distanceM}m'
      : '${(distanceM! / 1000).toStringAsFixed(1)}km';
}

// ════════════════════════════════════════════════════════════════════════════
// ── PlaceDetailScreen (탐색탭 & 모드A 공용 상세 화면)
// ════════════════════════════════════════════════════════════════════════════

class PlaceDetailScreen extends ConsumerStatefulWidget {
  const PlaceDetailScreen({super.key, required this.extra});
  final Object? extra;

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  late final _Detail? _detail;
  bool _detailLoading = false;
  String? _overview;
  String? _enrichedTel;
  String? _homepageUrl;
  String? _operatingInfo;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    final e = widget.extra;
    if (e is PlaceEntity) {
      _detail = _Detail.fromPlace(e);
      if (e.imageUrl != null) _images = [e.imageUrl!];
    } else if (e is RestaurantEntity) {
      _detail = _Detail.fromRestaurant(e);
    } else if (e is TouristRouteEntity) {
      _detail = _Detail.fromTouristRoute(e);
      if (e.imageUrls.isNotEmpty) _images = [e.imageUrls.first];
    } else {
      _detail = null;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final e = widget.extra;
    if (e is! PlaceEntity || e.source != PlaceSource.tourApi) return;
    final parts = e.id.split('_');
    if (parts.length < 2) return;
    final contentId = parts.last;
    final typeId = e.contentTypeId ?? 12;

    setState(() => _detailLoading = true);
    try {
      final data = await TourApiDetailDatasource().fetchDetail(
        contentId,
        typeId,
      );
      if (!mounted || data == null) return;
      final merged = List<String>.from(_images);
      for (final img in data.images) {
        if (!merged.contains(img)) merged.add(img);
      }
      setState(() {
        _overview = (data.overview?.isNotEmpty ?? false) ? data.overview : null;
        _enrichedTel = data.tel;
        _homepageUrl = data.homepageUrl;
        _operatingInfo = (data.operatingInfo?.isNotEmpty ?? false)
            ? data.operatingInfo
            : null;
        if (merged.isNotEmpty) _images = merged;
      });
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_detail == null) {
      return Scaffold(
        backgroundColor: kMapPanel,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                '장소 정보를 불러올 수 없습니다',
                style: AppTypography.bodyMute.copyWith(
                  fontWeight: FontWeight.w400,
                  color: Colors.white54,
                ),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  '돌아가기',
                  style: TextStyle(color: Color(0xFF03C75A)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final c = context.colors;
    final detail = _detail;
    final extra = widget.extra;
    final modeAState = ref.watch(modeAProvider);
    final canAddWaypoint = modeAState.waypoints.length < 3;
    final tel = _enrichedTel ?? detail.phone;

    return Scaffold(
      backgroundColor: kMapPanel,
      body: Stack(
        children: [
          // ── 스크롤 본문 ────────────────────────────────────────────
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ImageHeader(
                  detail: detail,
                  images: _images,
                  loading: _detailLoading && _images.isEmpty,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _NameSection(detail: detail),
                    const SizedBox(height: 16),
                    if (detail.showInfoRow) ...[
                      _RestaurantInfoRow(detail: detail),
                      const SizedBox(height: 12),
                    ],
                    if (detail.kcalDiff != null) ...[
                      _KcalDiffRow(diff: detail.kcalDiff!),
                      const SizedBox(height: 12),
                    ],
                    if (_overview != null) ...[
                      _OverviewSection(overview: _overview!),
                      const SizedBox(height: 12),
                    ],
                    if (detail.address != null ||
                        tel != null ||
                        _operatingInfo != null)
                      _ContactSection(
                        detail: detail,
                        overrideTel: tel,
                        operatingInfo: _operatingInfo,
                      ),
                    if (_homepageUrl != null) ...[
                      const SizedBox(height: 8),
                      _HomepageBtn(
                        url: _homepageUrl!,
                        onTap: () => _openUrl(_homepageUrl!),
                      ),
                    ],
                    if (detail.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _TagsSection(tags: detail.tags),
                    ],
                    const SizedBox(height: 96),
                  ]),
                ),
              ),
            ],
          ),

          // ── 상단 뒤로가기 버튼 ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _CircleBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 하단 버튼 (경로 설정 — 진입 경로와 무관하게 항상 표시) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: kMapPanel,
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: extra is TouristRouteEntity
                  ? _ModeBCourseButtons(route: extra)
                  : Row(
                      children: [
                        _RouteBtn(
                          label: '출발지',
                          color: c.success,
                          icon: Icons.trip_origin_rounded,
                          onTap: () {
                            ref
                                .read(modeAProvider.notifier)
                                .setOriginGps(
                                  detail.latitude,
                                  detail.longitude,
                                  detail.name,
                                );
                            ref
                                .read(mapModeProvider.notifier)
                                .set(MapMode.modeA);
                            context.pop();
                          },
                        ),
                        const SizedBox(width: 8),
                        _RouteBtn(
                          label: '도착지',
                          color: c.danger,
                          icon: Icons.place_rounded,
                          onTap: () {
                            // 이동수단은 Mode A 입력 패널에서 사용자가 직접
                            // 고른 뒤 검색해야 하므로 여기서 search()를 미리
                            // 호출하지 않는다 — 그러면 항상 기본값(walk)으로
                            // 강제 검색돼버린다.
                            ref
                                .read(modeAProvider.notifier)
                                .setDestCoords(
                                  detail.latitude,
                                  detail.longitude,
                                  detail.name,
                                );
                            ref
                                .read(mapModeProvider.notifier)
                                .set(MapMode.modeA);
                            context.pop();
                          },
                        ),
                        if (canAddWaypoint) ...[
                          const SizedBox(width: 8),
                          _RouteBtn(
                            label: '경유지',
                            color: c.accent,
                            icon: Icons.add_location_alt_rounded,
                            onTap: () {
                              final notifier = ref.read(modeAProvider.notifier);
                              notifier.addWaypoint(
                                RouteWaypoint(
                                  name: detail.name,
                                  latitude: detail.latitude,
                                  longitude: detail.longitude,
                                ),
                              );
                              ref
                                  .read(mapModeProvider.notifier)
                                  .set(MapMode.modeA);
                              final s = ref.read(modeAProvider);
                              if (s.originLat != null && s.destLat != null) {
                                notifier.search();
                              }
                              context.pop();
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 헤더 이미지 (TourAPI firstimage / FoodImageWidget 폴백)
// ════════════════════════════════════════════════════════════════════════════

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({
    required this.detail,
    this.images = const [],
    this.loading = false,
  });
  final _Detail detail;
  final List<String> images;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final imageH = MediaQuery.sizeOf(context).height * 0.30;
    final primaryUrl = images.isNotEmpty ? images.first : detail.imageUrl;

    Widget image;
    if (loading && primaryUrl == null) {
      image = Container(
        height: imageH,
        color: kMapPanelAlt,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    } else if (primaryUrl != null && primaryUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: primaryUrl,
        width: double.infinity,
        height: imageH,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (_, __) => Container(
          height: imageH,
          color: kMapPanelAlt,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white24,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _placeholderImage(imageH),
      );
    } else if (detail.isRestaurant) {
      image = FoodImageWidget(
        type: FoodImageWidget.fromString(detail.imageType),
        height: imageH,
      );
    } else {
      image = _placeholderImage(imageH);
    }

    return SizedBox(
      height: imageH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // 하단 그라디언트
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: imageH * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    kMapPanel.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage(double h) {
    return Container(
      height: h,
      color: kMapPanelAlt,
      child: const Center(
        child: Icon(Icons.landscape_rounded, size: 56, color: Colors.white12),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 이름 + 배지 섹션
// ════════════════════════════════════════════════════════════════════════════

class _NameSection extends StatelessWidget {
  const _NameSection({required this.detail});
  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = detail.badge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 뱃지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeLabel,
            style: AppTypography.tiny.copyWith(
              fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 이름
        Text(
          detail.name,
          style: AppTypography.titleSm.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        // 카테고리
        if (detail.category != null && detail.category!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detail.category!,
            style: AppTypography.label.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // 평점 (있을 때만)
        if (detail.rating > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 14,
                color: Color(0xFFFFC56E),
              ),
              const SizedBox(width: 4),
              Text(
                detail.rating.toStringAsFixed(1),
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 음식점 정보 (칼로리 · 거리 · 도보 시간)
// ════════════════════════════════════════════════════════════════════════════

class _RestaurantInfoRow extends StatelessWidget {
  const _RestaurantInfoRow({required this.detail});
  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _InfoPill(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF7A45),
            label: '약 ${detail.kcalEstimate} kcal',
          ),
          if (detail.menu != null && detail.menu!.isNotEmpty) ...[
            const SizedBox(width: 12),
            _InfoPill(
              icon: Icons.restaurant_rounded,
              color: const Color(0xFF03C75A),
              label: detail.menu!,
            ),
          ],
          if (detail.distanceLabel != null) ...[
            const SizedBox(width: 12),
            _InfoPill(
              icon: Icons.near_me_rounded,
              color: const Color(0xFF7C8AFF),
              label: detail.distanceLabel!,
            ),
          ],
          if (detail.walkMinutes != null) ...[
            const SizedBox(width: 12),
            _InfoPill(
              icon: Icons.directions_walk_rounded,
              color: Colors.white54,
              label: '도보 ${detail.walkMinutes}분',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 오늘 소모 칼로리 대비 이 메뉴의 칼로리 차이
// ════════════════════════════════════════════════════════════════════════════

class _KcalDiffRow extends StatelessWidget {
  const _KcalDiffRow({required this.diff});
  final int diff;

  @override
  Widget build(BuildContext context) {
    final label = diff == 0
        ? '오늘 소모한 칼로리와 정확히 일치해요'
        : diff > 0
        ? '오늘 소모한 칼로리보다 +$diff kcal 더 많아요'
        : '오늘 소모한 칼로리보다 ${diff.abs()} kcal 적어요';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF03C75A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF03C75A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            size: 16,
            color: Color(0xFF03C75A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF03C75A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 주소 / 전화번호 섹션
// ════════════════════════════════════════════════════════════════════════════

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.detail,
    this.overrideTel,
    this.operatingInfo,
  });
  final _Detail detail;
  final String? overrideTel;
  final String? operatingInfo;

  @override
  Widget build(BuildContext context) {
    final tel = overrideTel ?? detail.phone;
    final hasAddress = detail.address != null && detail.address!.isNotEmpty;
    final hasTel = tel != null && tel.isNotEmpty;
    final hasOp = operatingInfo != null && operatingInfo!.isNotEmpty;
    if (!hasAddress && !hasTel && !hasOp) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMapPanelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAddress) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detail.address!,
                    style: AppTypography.label.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasAddress && hasTel) const SizedBox(height: 10),
          if (hasTel)
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                Text(
                  tel,
                  style: AppTypography.label.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          if (hasOp) ...[
            if (hasAddress || hasTel) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    operatingInfo!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white54,
                      height: 1.45,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 개요 섹션
// ════════════════════════════════════════════════════════════════════════════

class _OverviewSection extends StatefulWidget {
  const _OverviewSection({required this.overview});
  final String overview;

  @override
  State<_OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<_OverviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kMapPanelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined, size: 14, color: Colors.white38),
                SizedBox(width: 6),
                Text(
                  '소개',
                  style: AppTypography.tiny.copyWith(
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.overview,
              style: AppTypography.label.copyWith(
                color: Colors.white70,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
              maxLines: _expanded ? null : 4,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (!_expanded) ...[
              const SizedBox(height: 4),
              Text(
                '더 보기',
                style: AppTypography.tiny.copyWith(color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 홈페이지 버튼
// ════════════════════════════════════════════════════════════════════════════

class _HomepageBtn extends StatelessWidget {
  const _HomepageBtn({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kMapPanelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new_rounded, size: 15, color: Colors.white38),
            SizedBox(width: 8),
            Text(
              '공식 홈페이지',
              style: AppTypography.label.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 태그 섹션 (음식점용)
// ════════════════════════════════════════════════════════════════════════════

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                t,
                style: AppTypography.tiny.copyWith(color: Colors.white70),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── 공용 소형 위젯
// ════════════════════════════════════════════════════════════════════════════

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B 코스 선택 버튼
// ════════════════════════════════════════════════════════════════════════════

class _ModeBCourseButtons extends ConsumerWidget {
  const _ModeBCourseButtons({required this.route});
  final TouristRouteEntity route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routeSearchProvider).routes;
    final idx = routes.indexWhere((r) => r.id == route.id);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (idx >= 0) {
                ref.read(routeSearchProvider.notifier).selectRoute(idx);
              }
              context.pop();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF03C75A).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF03C75A).withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 17, color: Color(0xFF03C75A)),
                  SizedBox(height: 2),
                  Text(
                    '지도에서 보기',
                    style: AppTypography.tiny.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF03C75A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              if (idx >= 0) {
                ref.read(routeSearchProvider.notifier).selectRoute(idx);
              }
              ref.read(routeSearchProvider.notifier).startRoute();
              context.pop();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF03C75A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation_rounded, size: 17, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '이 코스로 시작하기',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteBtn extends StatelessWidget {
  const _RouteBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.tiny.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
