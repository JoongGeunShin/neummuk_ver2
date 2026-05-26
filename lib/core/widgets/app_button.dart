import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

enum ButtonVariant { primary, secondary, ghost, danger }
enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.lg,
    this.icon,
    this.iconRight,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? iconRight;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (h, px, fs, gap, br) = switch (size) {
      ButtonSize.sm => (36.0, 14.0, 13.0, 6.0, 12.0),
      ButtonSize.md => (44.0, 18.0, 14.0, 8.0, 14.0),
      ButtonSize.lg => (56.0, 24.0, 16.0, 10.0, 18.0),
    };
    final (bg, fg, border) = switch (variant) {
      ButtonVariant.primary => (c.primary, c.onPrimary, BorderSide.none),
      ButtonVariant.secondary =>
        (c.surfaceHi, c.text, BorderSide(color: c.outline)),
      ButtonVariant.ghost =>
        (Colors.transparent, c.text, BorderSide(color: c.outline)),
      ButtonVariant.danger => (c.secondary, Colors.white, BorderSide.none),
    };

    return SizedBox(
      height: h,
      width: fullWidth ? double.infinity : null,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: px),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(br),
            side: border,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fs + 4),
              SizedBox(width: gap),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (iconRight != null) ...[
              SizedBox(width: gap),
              Icon(iconRight, size: fs + 4),
            ],
          ],
        ),
      ),
    );
  }
}
