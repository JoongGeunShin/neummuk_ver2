import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/map/presentation/screens/app_map_screen.dart';
import '../../../../features/map/presentation/widgets/mode_b_overlay.dart';
import '../providers/mode_b_provider.dart';

class ModeBRouteScreen extends ConsumerWidget {
  const ModeBRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = ref.watch(selectedFoodProvider);

    if (food == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.go('/explore'));
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/explore');
      },
      child: AppMapScreen(
        overlayBuilder: (ctx, ctrl, events) =>
            ModeBOverlay(controller: ctrl, events: events),
      ),
    );
  }
}
