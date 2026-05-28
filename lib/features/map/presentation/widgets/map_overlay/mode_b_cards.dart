part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Route card ────────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

void _showImageGallery(BuildContext context, TouristRouteEntity route) {
  if (!route.hasImages) return;
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ImageGalleryDialog(route: route),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.transport,
    required this.isSelected,
    required this.onTap,
  });

  final TouristRouteEntity route;
  final String transport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF03C75A).withValues(alpha: 0.12)
              : _kPanelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF03C75A) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                transport == 'walk'
                    ? Icons.hiking_rounded
                    : Icons.directions_bike_rounded,
                size: 15,
                color: isSelected ? const Color(0xFF03C75A) : _kWhite45,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(route.name,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF03C75A) : _kWhite87,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
              if (route.isLocal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF03C75A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('내 지역',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF03C75A), fontWeight: FontWeight.w700)),
                ),
              ] else if (route.region != null) ...[
                const SizedBox(width: 6),
                Text(route.region!,
                    style: const TextStyle(
                        fontSize: 11, color: _kWhite45, fontWeight: FontWeight.w600)),
              ],
              if (route.gpxpath != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.route_rounded, size: 13, color: _kWhite45),
              ],
              if (route.hasImages) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showImageGallery(context, route),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.photo_library_rounded,
                        size: 15, color: Color(0xFF03C75A)),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (route.distanceFromUserM != null) ...[
                MapInfoChip(
                  icon: Icons.near_me_rounded,
                  label: route.distanceFromUserM! < 1000
                      ? '${route.distanceFromUserM}m'
                      : '${(route.distanceFromUserM! / 1000).toStringAsFixed(1)}km',
                  color: const Color(0xFF03C75A),
                ),
                const SizedBox(width: 8),
              ],
              if (route.hasDetailInfo) ...[
                MapInfoChip(
                    icon: Icons.straighten_rounded,
                    label: '${route.distanceKm.toStringAsFixed(1)}km'),
                const SizedBox(width: 8),
                MapInfoChip(
                    icon: Icons.schedule_rounded, label: '${route.durationMinutes}분'),
                const SizedBox(width: 8),
                MapInfoChip(
                    icon: Icons.local_fire_department_rounded, label: '~${route.kcal}kcal'),
              ] else ...[
                const MapInfoChip(icon: Icons.info_outline_rounded, label: '상세정보 없음'),
              ],
              if (route.tags.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(route.tags.first,
                    style: const TextStyle(fontSize: 11, color: _kWhite45)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Image gallery dialog ──────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({required this.route});
  final TouristRouteEntity route;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls  = widget.route.imageUrls;
    final total = urls.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: _kPanel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(children: [
                  Expanded(
                    child: Text(widget.route.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: _kWhite87),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: _kWhite45),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (ctx, i) => CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, __) => const ColoredBox(
                      color: _kPanelAlt,
                      child: Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: _kPanelAlt,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 32, color: _kWhite45),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < total; i++) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _current ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _current
                              ? const Color(0xFF03C75A)
                              : _kHandle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (i < total - 1) const SizedBox(width: 5),
                    ],
                    if (total > 1) ...[
                      const SizedBox(width: 12),
                      Text('${_current + 1} / $total',
                          style: const TextStyle(
                              fontSize: 11, color: _kWhite45, fontWeight: FontWeight.w600)),
                    ],
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
