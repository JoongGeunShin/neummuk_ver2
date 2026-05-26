import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/map_widgets.dart';
import '../providers/map_mode_provider.dart';
import '../widgets/explore_overlay.dart';
import '../widgets/mode_a_overlay.dart';
import '../widgets/mode_b_overlay.dart';
import 'app_map_screen.dart';

// 단일 NaverMap 인스턴스. 모드 전환 시 지도를 재생성하지 않는다.
class UnifiedMapScreen extends StatelessWidget {
  const UnifiedMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppMapScreen(
      activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
      overlayBuilder: (ctx, ctrl, events) =>
          _UnifiedOverlay(controller: ctrl, masterEvents: events),
    );
  }
}

// ── Unified overlay ───────────────────────────────────────────────────────────

class _UnifiedOverlay extends ConsumerStatefulWidget {
  const _UnifiedOverlay({
    required this.controller,
    required this.masterEvents,
  });

  final NaverMapController? controller;
  final MapEventSink masterEvents;

  @override
  ConsumerState<_UnifiedOverlay> createState() => _UnifiedOverlayState();
}

class _UnifiedOverlayState extends ConsumerState<_UnifiedOverlay> {
  // 각 모드에 독립적인 이벤트 싱크 — 오버레이가 서로 간섭하지 않는다.
  final _exploreSink = MapEventSink();
  final _modeASink = MapEventSink();
  final _modeBSink = MapEventSink();

  @override
  void initState() {
    super.initState();
    _bindMasterEvents();
  }

  void _bindMasterEvents() {
    widget.masterEvents.onMapTapped = (p, ll) =>
        _activeSink.onMapTapped?.call(p, ll);
    widget.masterEvents.onLongTapped = (p, ll) =>
        _activeSink.onLongTapped?.call(p, ll);
    widget.masterEvents.onCameraIdle = () => _activeSink.onCameraIdle?.call();
  }

  MapEventSink get _activeSink => switch (ref.read(mapModeProvider)) {
        MapMode.explore => _exploreSink,
        MapMode.modeA => _modeASink,
        MapMode.modeB => _modeBSink,
      };

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(mapModeProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // fit: expand → 자식 오버레이에 tight constraints 전달.
    // DraggableScrollableSheet(ModeBOverlay)는 tight constraints 없으면 오작동.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (mode == MapMode.explore)
          ExploreOverlay(controller: widget.controller, events: _exploreSink),
        if (mode == MapMode.modeA)
          ModeAOverlay(controller: widget.controller, events: _modeASink),
        if (mode == MapMode.modeB)
          ModeBOverlay(controller: widget.controller, events: _modeBSink),

        // 탐색 ↔ 경로 토글 (모드B에서는 숨김 — 음식 선택 플로우라 별도)
        if (mode != MapMode.modeB)
          Positioned(
            left: 12,
            bottom: bottomPad + 16,
            child: _ModeToggle(
              mode: mode,
              onExplore: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.explore),
              onModeA: () =>
                  ref.read(mapModeProvider.notifier).set(MapMode.modeA),
            ),
          ),
      ],
    );
  }
}

// ── 모드 토글 ─────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onExplore,
    required this.onModeA,
  });

  final MapMode mode;
  final VoidCallback onExplore;
  final VoidCallback onModeA;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleTab(
            icon: Icons.explore_rounded,
            label: '탐색',
            active: mode == MapMode.explore,
            onTap: onExplore,
          ),
          _ToggleTab(
            icon: Icons.route_rounded,
            label: '경로',
            active: mode == MapMode.modeA,
            onTap: onModeA,
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kMapGreen.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : kMapWhite45),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : kMapWhite45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
