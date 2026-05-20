import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

class SegmentOption {
  const SegmentOption({required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final IconData? icon;
}

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<SegmentOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final idx = options.indexWhere((o) => o.value == value);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.outline),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          // Sliding indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: idx * ((context.screenWidth - 48) / options.length),
            top: 0,
            bottom: 0,
            width: (context.screenWidth - 48) / options.length,
            child: Container(
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: c.primaryGlow,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Buttons
          Row(
            children: options.map((opt) {
              final on = value == opt.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.icon != null) ...[
                          Icon(
                            opt.icon,
                            size: 16,
                            color: on ? c.onPrimary : c.textMuted,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              color: on ? c.onPrimary : c.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
