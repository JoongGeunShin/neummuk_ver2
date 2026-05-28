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
    final sourceLabel = switch (place.source) {
      PlaceSource.tourApi => ('장소', const Color(0xFF03C75A)),
      PlaceSource.kakaoLocal => ('장소', const Color(0xFF03C75A)),
      PlaceSource.both => ('⭐ 추천', const Color(0xFFFFAB00)),
    };

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _kHandle, borderRadius: BorderRadius.circular(2),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sourceLabel.$2.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(sourceLabel.$1,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sourceLabel.$2)),
                              ),
                              const SizedBox(height: 6),
                              Text(place.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (place.category != null && place.category!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(place.category!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (place.address != null && place.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: _kWhite45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(place.address!,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                    if (place.phone != null && place.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 15, color: _kWhite45),
                        const SizedBox(width: 4),
                        Text(place.phone!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      _PlaceRouteBtn(label: '출발지', color: const Color(0xFF2ECC71),
                          onTap: () => onSetOrigin(place)),
                      const SizedBox(width: 8),
                      _PlaceRouteBtn(label: '도착지', color: const Color(0xFFE74C3C),
                          onTap: () => onSetDest(place)),
                      if (canAddWaypoint) ...[
                        const SizedBox(width: 8),
                        _PlaceRouteBtn(label: '경유지', color: const Color(0xFFF39C12),
                            onTap: () => onAddWaypoint(place)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onViewDetail(place),
                      child: Container(
                        width: double.infinity, height: 36,
                        decoration: BoxDecoration(
                          color: _kPanelAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 13, color: _kWhite45),
                            SizedBox(width: 6),
                            Text('자세히 보기',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: _kWhite45)),
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

class _PlaceRouteBtn extends StatelessWidget {
  const _PlaceRouteBtn({required this.label, required this.color, required this.onTap});
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
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
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

  String? _trimCategory(String? cat) {
    if (cat == null || cat.isEmpty) return null;
    final parts = cat.split(RegExp(r'[>·,]'));
    return parts.last.trim().isNotEmpty ? parts.last.trim() : null;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _kHandle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${places.length}곳',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: _kGreen)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('이 지역 장소 목록',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
              const Divider(color: Colors.white12, height: 1, thickness: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: places.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    final isBoth = place.source == PlaceSource.both;
                    final dotColor = isBoth ? const Color(0xFFFFAB00) : _kGreen;
                    final trimmedCat = _trimCategory(place.category);
                    return InkWell(
                      onTap: () => onTapPlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(place.name,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w700,
                                        color: Colors.white, letterSpacing: -0.2),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (trimmedCat != null) ...[
                                  const SizedBox(height: 2),
                                  Text(trimmedCat,
                                      style: const TextStyle(fontSize: 12, color: _kWhite45),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white30),
                        ]),
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
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Column(children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _kHandle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.place_rounded, size: 16, color: _kGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('검색 결과 ${places.length}곳',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white54),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ]),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1, thickness: 1),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: places.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final place = places[index];
                return _ExploreListItem(place: place, onTap: () => onTapPlace(place));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreListItem extends StatelessWidget {
  const _ExploreListItem({required this.place, required this.onTap});
  final PlaceEntity place;
  final VoidCallback onTap;

  String? _trimCategory(String? cat) {
    if (cat == null || cat.isEmpty) return null;
    final parts = cat.split(RegExp(r'[>·,]'));
    return parts.last.trim().isNotEmpty ? parts.last.trim() : null;
  }

  @override
  Widget build(BuildContext context) {
    final isBoth = place.source == PlaceSource.both;
    final dotColor = isBoth ? const Color(0xFFFFAB00) : const Color(0xFF03C75A);
    final trimmedCat = _trimCategory(place.category);

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
                width: 8, height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
                        child: Text(place.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.2),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isBoth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('⭐ 추천',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFAB00))),
                        ),
                      ],
                    ],
                  ),
                  if (trimmedCat != null) ...[
                    const SizedBox(height: 3),
                    Text(trimmedCat,
                        style: const TextStyle(
                            fontSize: 12, color: _kWhite45, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (place.address != null && place.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: _kWhite45),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(place.address!,
                            style: const TextStyle(fontSize: 12, color: _kWhite45),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white30),
            ),
          ],
        ),
      ),
    );
  }
}
