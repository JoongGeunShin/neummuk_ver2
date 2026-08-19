part of '../map_overlay.dart';

// ── Explore place sheet ────────────────────────────────────────────────────

class _ExplorePlaceSheet extends StatelessWidget {
  const _ExplorePlaceSheet({
    required this.place,
    required this.onClose,
    required this.canAddWaypoint,
    required this.onSetOrigin,
    required this.onSetDest,
    required this.onAddWaypoint,
    required this.onViewDetail,
  });
  final PlaceEntity place;
  final bool canAddWaypoint;
  final VoidCallback onClose;
  final ValueChanged<PlaceEntity> onSetOrigin;
  final ValueChanged<PlaceEntity> onSetDest;
  final ValueChanged<PlaceEntity> onAddWaypoint;
  final ValueChanged<PlaceEntity> onViewDetail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sourceLabel = switch (place.source) {
      PlaceSource.tourApi => ('장소', c.success),
      PlaceSource.kakaoLocal => ('장소', c.success),
      PlaceSource.both => ('⭐ 추천', c.accent),
    };

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sourceLabel.$2.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sourceLabel.$1,
                                  style: AppTypography.tiny.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: sourceLabel.$2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place.name,
                                style: AppTypography.subtitle.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (place.menu != null && place.kcalEstimate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 13,
                            color: _kWhite45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${place.menu} · ${place.kcalEstimate}kcal',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (place.kcalDiff != null) ...[
                        const SizedBox(height: 6),
                        _KcalDiffBadge(diff: place.kcalDiff!),
                      ],
                    ] else if (place.category != null &&
                        place.category!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.category!,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (place.address != null && place.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: _kWhite45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.address!,
                              style: AppTypography.label.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (place.phone != null && place.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: _kWhite45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.phone!,
                            style: AppTypography.label.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _PlaceRouteBtn(
                          label: '출발지',
                          color: c.success,
                          onTap: () => onSetOrigin(place),
                        ),
                        const SizedBox(width: 8),
                        _PlaceRouteBtn(
                          label: '도착지',
                          color: c.danger,
                          onTap: () => onSetDest(place),
                        ),
                        if (canAddWaypoint) ...[
                          const SizedBox(width: 8),
                          _PlaceRouteBtn(
                            label: '경유지',
                            color: c.accent,
                            onTap: () => onAddWaypoint(place),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onViewDetail(place),
                      child: Container(
                        width: double.infinity,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _kPanelAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 13,
                              color: _kWhite45,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '자세히 보기',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _kWhite45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 매칭된 음식 kcal과 비교 기준(오늘 소모/필요 칼로리) 간 차이를 보여주는 배지.
/// diff==0: "오늘 소모량과 일치" / diff>0: "오늘보다 +Nkcal" / diff<0: "오늘보다 -Nkcal".
class _KcalDiffBadge extends StatelessWidget {
  const _KcalDiffBadge({required this.diff});
  final int diff;

  @override
  Widget build(BuildContext context) {
    final label = diff == 0
        ? '오늘 소모량과 일치'
        : '오늘보다 ${diff > 0 ? '+' : ''}$diff kcal';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows_rounded, size: 13, color: _kGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.tiny.copyWith(
              fontWeight: FontWeight.w700,
              color: _kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRouteBtn extends StatelessWidget {
  const _PlaceRouteBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Cluster panel ─────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ClusterPanel extends StatelessWidget {
  const _ClusterPanel({
    required this.places,
    required this.onClose,
    required this.onTapPlace,
  });
  final List<PlaceEntity> places;
  final VoidCallback onClose;
  final ValueChanged<PlaceEntity> onTapPlace;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
          ),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${places.length}곳',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이 지역 장소 목록',
                        style: AppTypography.bodyMute.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white54,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1, thickness: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white10,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    final isBoth = place.source == PlaceSource.both;
                    final dotColor = isBoth
                        ? context.colors.accent
                        : context.colors.success;
                    final subtitle = _placeSubtitle(place);
                    return InkWell(
                      onTap: () => onTapPlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: AppTypography.bodyMute.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w400,
                                        color: _kWhite45,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.white30,
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
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Explore list sheet ────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ExploreListSheet extends StatelessWidget {
  const _ExploreListSheet({
    required this.scrollController,
    required this.places,
    required this.onClose,
    required this.onTapPlace,
  });
  final ScrollController scrollController;
  final List<PlaceEntity> places;
  final VoidCallback onClose;
  final ValueChanged<PlaceEntity> onTapPlace;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _kPanel,
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // 헤더 — scrollController에 연결되어 드래그로 시트 확장/축소 가능
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: _kGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '검색 결과 ${places.length}곳',
                            style: AppTypography.bodyMute.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Colors.white54,
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1, thickness: 1),
                ],
              ),
            ),
            // 목록
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ExploreListItem(
                      place: places[index],
                      onTap: () => onTapPlace(places[index]),
                    ),
                    if (index < places.length - 1)
                      const Divider(
                        color: Colors.white10,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                ),
                childCount: places.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ExploreListItem extends StatelessWidget {
  const _ExploreListItem({required this.place, required this.onTap});
  final PlaceEntity place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBoth = place.source == PlaceSource.both;
    final dotColor = isBoth ? context.colors.accent : context.colors.success;
    final subtitle = _placeSubtitle(place);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBoth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⭐ 추천',
                            style: AppTypography.micro.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(color: _kWhite45),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (place.address != null && place.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: _kWhite45,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place.address!,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: _kWhite45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
