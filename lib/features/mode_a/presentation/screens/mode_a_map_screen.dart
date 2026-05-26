import 'package:flutter/material.dart';

import '../../../../features/map/presentation/screens/app_map_screen.dart';
import '../../../../features/map/presentation/widgets/mode_a_overlay.dart';

class ModeAMapScreen extends StatelessWidget {
  const ModeAMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppMapScreen(
      overlayBuilder: (ctx, ctrl, events) =>
          ModeAOverlay(controller: ctrl, events: events),
    );
  }
}
