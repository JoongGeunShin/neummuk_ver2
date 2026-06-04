part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Route card ────────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

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
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _kWhite45),
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

