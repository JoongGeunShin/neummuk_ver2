import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../widgets/map_overlay.dart';
import 'app_map_screen.dart';

// 단일 NaverMap 인스턴스. 모드 전환 시 지도를 재생성하지 않는다.
class UnifiedMapScreen extends StatelessWidget {
  const UnifiedMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppMapScreen(
      activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
      overlayBuilder: (ctx, ctrl, events) =>
          MapOverlay(controller: ctrl, events: events),
    );
  }
}
