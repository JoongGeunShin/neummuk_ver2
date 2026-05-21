import 'dart:math' as math;
import 'package:flutter/material.dart';

/// FAB 위치에서 원형으로 화면이 펼쳐지는 페이지 전환.
/// [sourceCenter]: 전환 시작점 (전역 좌표)
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({
    required Widget page,
    required this.sourceCenter,
  }) : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 480),
          reverseTransitionDuration: const Duration(milliseconds: 340),
          transitionsBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );
            return AnimatedBuilder(
              animation: curved,
              builder: (_, child) => ClipPath(
                clipper: _CircularRevealClipper(
                  fraction: curved.value,
                  center: sourceCenter,
                ),
                child: child,
              ),
              child: child,
            );
          },
        );

  final Offset sourceCenter;
}

class _CircularRevealClipper extends CustomClipper<Path> {
  const _CircularRevealClipper({
    required this.fraction,
    required this.center,
  });

  final double fraction;
  final Offset center;

  @override
  Path getClip(Size size) {
    final maxDx = math.max(center.dx, size.width - center.dx);
    final maxDy = math.max(center.dy, size.height - center.dy);
    final maxRadius = math.sqrt(maxDx * maxDx + maxDy * maxDy) * 1.05;
    return Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: maxRadius * fraction),
      );
  }

  @override
  bool shouldReclip(_CircularRevealClipper old) =>
      old.fraction != fraction || old.center != center;
}
