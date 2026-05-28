part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode A 경로 입력 패널 ──────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeARoutePanel extends StatelessWidget {
  const _ModeARoutePanel({
    required this.state,
    required this.locating,
    required this.onTapOrigin,
    required this.onGpsOrigin,
    required this.onTapDest,
    required this.onClearDest,
    required this.onSetTransport,
    required this.onRemoveWaypoint,
    required this.onReorderWaypoints,
    required this.onSearch,
    required this.onBack,
  });

  final ModeAState state;
  final bool locating;
  final VoidCallback onTapOrigin;
  final VoidCallback onGpsOrigin;
  final VoidCallback onTapDest;
  final VoidCallback onClearDest;
  final ValueChanged<String> onSetTransport;
  final ValueChanged<int> onRemoveWaypoint;
  final void Function(int oldIdx, int newIdx) onReorderWaypoints;
  final VoidCallback? onSearch;
  final VoidCallback onBack;

  static const _transports = [
    ('walk', '도보', Icons.directions_walk_rounded),
    ('bike', '자전거', Icons.directions_bike_rounded),
    ('transit', '대중교통', Icons.directions_bus_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kMapPanel,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: Row(children: [
                MapControlButton(
                  onTap: onBack,
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: kMapWhite87),
                ),
                const SizedBox(width: 10),
                const Text('경로 찾기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kMapWhite87)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kMapPanelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  MapFieldRow(
                    dot: const MapWaypointDot(type: MapWaypointDotType.origin),
                    child: locating
                        ? const Row(children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kMapWhite45),
                            ),
                            SizedBox(width: 8),
                            Text('위치 확인 중...',
                                style: TextStyle(
                                    color: kMapWhite45, fontSize: 14, fontWeight: FontWeight.w500)),
                          ])
                        : Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: onTapOrigin,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  state.from.isEmpty ? '출발지를 설정해주세요' : state.from,
                                  style: TextStyle(
                                    color: state.from.isEmpty ? kMapWhite45 : kMapWhite87,
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: onGpsOrigin,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.my_location_rounded, size: 18, color: kMapWhite45),
                              ),
                            ),
                          ]),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 16),
                  MapFieldRow(
                    dot: const MapWaypointDot(type: MapWaypointDotType.dest),
                    child: GestureDetector(
                      onTap: onTapDest,
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            state.to.isEmpty ? '어디로 갈까요?' : state.to,
                            style: TextStyle(
                              color: state.to.isEmpty ? kMapWhite45 : kMapWhite87,
                              fontSize: 14, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (state.to.isNotEmpty)
                          GestureDetector(
                            onTap: onClearDest,
                            child: const Icon(Icons.cancel_rounded, size: 16, color: kMapWhite45),
                          ),
                      ]),
                    ),
                  ),
                  if (state.waypoints.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.waypoints.length,
                      onReorderItem: onReorderWaypoints,
                      buildDefaultDragHandles: false,
                      itemBuilder: (ctx, i) {
                        final wp = state.waypoints[i];
                        return Column(
                          key: ValueKey('wp_$i'),
                          children: [
                            const Divider(color: Colors.white12, height: 1, indent: 16),
                            MapFieldRow(
                              dot: const MapWaypointDot(type: MapWaypointDotType.waypoint),
                              child: Row(children: [
                                Expanded(
                                  child: Text(wp.name,
                                      style: const TextStyle(
                                          color: kMapWhite87, fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.drag_handle_rounded,
                                        size: 18, color: kMapWhite45),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => onRemoveWaypoint(i),
                                  child: const Icon(Icons.close_rounded,
                                      size: 16, color: kMapWhite45),
                                ),
                              ]),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  ..._transports.map((t) {
                    final (id, label, icon) = t;
                    final on = state.transport == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: GestureDetector(
                        onTap: () => onSetTransport(id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: on ? kMapGreen.withValues(alpha: 0.9) : kMapPanelAlt,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: on ? kMapGreen : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: on ? Colors.white : kMapWhite45),
                              const SizedBox(width: 3),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: on ? Colors.white : kMapWhite45)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  GestureDetector(
                    onTap: onSearch,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: onSearch != null ? kMapGreen : kMapPanelAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, size: 14,
                              color: onSearch != null ? Colors.white : kMapWhite45),
                          const SizedBox(width: 5),
                          Text('코스 생성',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: onSearch != null ? Colors.white : kMapWhite45)),
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
    );
  }
}
