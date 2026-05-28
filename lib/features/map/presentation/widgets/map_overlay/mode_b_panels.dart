part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B top bar ────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeBTopBar extends StatelessWidget {
  const _ModeBTopBar({required this.food, required this.onBack});

  final FoodEntity food;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(children: [
            MapControlButton(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kWhite87),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kPanelAlt, borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(food.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('내 주변 산책로',
                          style: TextStyle(
                              fontSize: 10, color: _kWhite45, fontWeight: FontWeight.w700)),
                      Text('${food.name} · ${food.kcal} kcal',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _kWhite87)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Mode B bottom panel ───────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ModeBBottomPanel extends StatelessWidget {
  const _ModeBBottomPanel({
    required this.scrollController,
    required this.state,
    required this.food,
    required this.pos,
    required this.isLocating,
    required this.onSearch,
    required this.onTransportChange,
    required this.onSelectRoute,
    required this.onStartTap,
  });

  final ScrollController scrollController;
  final RouteSearchState state;
  final FoodEntity food;
  final Position? pos;
  final bool isLocating;
  final VoidCallback onSearch;
  final void Function(String) onTransportChange;
  final void Function(int) onSelectRoute;
  final VoidCallback onStartTap;

  @override
  Widget build(BuildContext context) {
    final selected  = state.selectedRoute;
    final hasRoutes = state.routes.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: _kPanel,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: _kHandle, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  if (hasRoutes) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.wp(4)),
                      child: _TransportToggle(
                          value: state.transport, onChanged: onTransportChange),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (isLocating)
              const SliverFillRemaining(
                child: Center(
                  child: Text('위치를 확인하는 중...',
                      style: TextStyle(
                          color: _kWhite45, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              )
            else if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF03C75A), strokeWidth: 2),
                ),
              )
            else if (state.routes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_outlined, size: 36, color: _kWhite45),
                      const SizedBox(height: 12),
                      const Text('현재 위치 주변 코스를 찾아보세요',
                          style: TextStyle(
                              color: _kWhite45, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03C75A),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('주변 코스 검색',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pos != null
                            ? '현재 위치 기준으로 검색합니다'
                            : 'GPS 권한이 없어 기본 위치를 사용합니다',
                        style: const TextStyle(fontSize: 11, color: _kWhite45),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RouteCard(
                      route: state.routes[i],
                      transport: state.transport,
                      isSelected: i == state.selectedRouteIdx,
                      onTap: () => onSelectRoute(i),
                    ),
                    childCount: state.routes.length,
                  ),
                ),
              ),
            if (selected != null)
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.wp(4), 4, context.wp(4), 8),
                    child: GestureDetector(
                      onTap: onStartTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF03C75A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('이 코스로 시작하기',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Transport toggle ──────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _TransportToggle extends StatelessWidget {
  const _TransportToggle({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(color: _kPanelAlt, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _ToggleItem(
            label: '걷기',
            icon: Icons.directions_walk_rounded,
            selected: value == 'walk',
            onTap: () => onChanged('walk')),
        _ToggleItem(
            label: '자전거',
            icon: Icons.directions_bike_rounded,
            selected: value == 'bike',
            onTap: () => onChanged('bike')),
      ]),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? _kPanel : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? _kWhite87 : _kWhite45),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: selected ? _kWhite87 : _kWhite45)),
            ],
          ),
        ),
      ),
    );
  }
}
