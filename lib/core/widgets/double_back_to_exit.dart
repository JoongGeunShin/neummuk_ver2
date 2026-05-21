import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child});

  final Widget child;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressed != null &&
            now.difference(_lastBackPressed!) <= const Duration(seconds: 2)) {
          await SystemNavigator.pop();
          return;
        }

        _lastBackPressed = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('앱을 종료하시려면 한 번 더 눌러주세요.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: widget.child,
    );
  }
}
