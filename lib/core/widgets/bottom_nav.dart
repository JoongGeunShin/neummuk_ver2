import 'package:flutter/material.dart';
import '../utils/context_ext.dart';

enum NavTab { home, search, record, me }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final NavTab activeTab;
  final ValueChanged<NavTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tabs = [
      (NavTab.home, '홈', Icons.restaurant_rounded),
      (NavTab.search, '탐색', Icons.explore_rounded),
      (NavTab.record, '내 기록', Icons.show_chart_rounded),
      (NavTab.me, 'MY', Icons.person_rounded),
    ];

    // SafeArea(top: false) 가 내비게이션 바 높이만큼 하단 패딩을 자동 추가
    return SafeArea(
      top: false,
      child: Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
        // border: Border.all(color: c.outline)
      ),
      // margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((t) {
          final (tab, label, icon) = t;
          final on = activeTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 28,
                    decoration: BoxDecoration(
                      color: on ? c.primarySoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: on ? c.primary : c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: on ? c.primary : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      ),  // Container
    );    // SafeArea
  }
}
