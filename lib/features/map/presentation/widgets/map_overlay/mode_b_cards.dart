part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Route card
// ════════════════════════════════════════════════════════════════════════════

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.transport,
    required this.isSelected,
    required this.onTap,
    this.onStart,
  });

  final TouristRouteEntity route;
  final String transport;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                transport == 'walk' ? Icons.hiking_rounded : Icons.directions_bike_rounded,
                size: 15,
                color: isSelected ? c.primary : c.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(route.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? c.primary : c.text,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
              if (route.isLocal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.primarySoft, borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('내 지역',
                      style: TextStyle(
                          fontSize: 10, color: c.primary, fontWeight: FontWeight.w700)),
                ),
              ] else if (route.region != null) ...[
                const SizedBox(width: 6),
                Text(route.region!,
                    style: TextStyle(
                        fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
              ],
              if (route.gpxpath != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.route_rounded, size: 13, color: c.textMuted),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16, color: c.textMuted),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (route.distanceFromUserM != null) ...[
                MapInfoChip(
                  icon: Icons.near_me_rounded,
                  label: route.distanceFromUserM! < 1000
                      ? '${route.distanceFromUserM}m'
                      : '${(route.distanceFromUserM! / 1000).toStringAsFixed(1)}km',
                  color: c.primary,
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
                    style: TextStyle(fontSize: 11, color: c.textMuted)),
              ],
            ]),
            // 선택된 카드에 안내 시작 버튼
            if (isSelected && onStart != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: c.primary, borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, size: 15, color: c.onPrimary),
                      const SizedBox(width: 6),
                      Text('안내 시작',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.onPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
