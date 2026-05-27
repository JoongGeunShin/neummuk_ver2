// ─── map/presentation/common/map_ui_atoms.dart ───────────────────────────────
//
// 지도 화면 전체에서 공유하는 소형 위젯 모음.
// map_overlay, mode_a_overlay, explore_overlay, mode_b_overlay 모두에서 재사용.
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../core/widgets/map_widgets.dart';

// ─── Sheet drag handle ────────────────────────────────────────────────────────

class MapSheetHandle extends StatelessWidget {
  const MapSheetHandle({super.key, this.topPadding = 10.0, this.width = 40.0});

  final double topPadding;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: topPadding, bottom: 4),
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: kMapHandle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Field row (경로 입력 패널 한 줄) ─────────────────────────────────────────

class MapFieldRow extends StatelessWidget {
  const MapFieldRow({super.key, required this.dot, required this.child});

  final Widget dot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: dot)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Waypoint dot (출발지 / 도착지 / 경유지 구분 점) ──────────────────────────

enum MapWaypointDotType { origin, dest, waypoint }

class MapWaypointDot extends StatelessWidget {
  const MapWaypointDot({
    super.key,
    this.type = MapWaypointDotType.origin,
  });

  final MapWaypointDotType type;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      MapWaypointDotType.dest => const Icon(
          Icons.place_rounded,
          size: 14,
          color: Color(0xFFFF4D6D),
        ),
      MapWaypointDotType.waypoint => const Icon(
          Icons.add_location_alt_rounded,
          size: 14,
          color: Color(0xFFFFC56E),
        ),
      MapWaypointDotType.origin => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF7C8AFF),
            border: Border.all(color: Colors.white54, width: 1.5),
          ),
        ),
    };
  }
}

// ─── Location action button (출발지 / 도착지 / 경유지 설정) ──────────────────

class MapLocationActionBtn extends StatelessWidget {
  const MapLocationActionBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kMapWhite87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info chip (아이콘 + 텍스트 한 줄) ───────────────────────────────────────

class MapInfoChip extends StatelessWidget {
  const MapInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kMapWhite45;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
        ),
      ],
    );
  }
}

// ─── Marker dot (탐색 마커 원형 점) ──────────────────────────────────────────

class MapMarkerDot extends StatelessWidget {
  const MapMarkerDot({super.key, required this.color, this.star = false});

  final Color color;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: star
          ? const Center(
              child: Text(
                '★',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Route marker dot (경로 출발·도착 마커, A / B 라벨) ──────────────────────

class MapRouteMarkerDot extends StatelessWidget {
  const MapRouteMarkerDot({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
