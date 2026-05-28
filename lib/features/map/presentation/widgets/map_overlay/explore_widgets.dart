part of '../map_overlay.dart';

// ════════════════════════════════════════════════════════════════════════════
// ── Explore top panel ─────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ExploreTopPanel extends StatelessWidget {
  const _ExploreTopPanel({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.onClose,
    required this.onSearch,
    required this.onCategoryTap,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final VoidCallback onClose;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  MapControlButton(
                    onTap: onClose,
                    child: const Icon(Icons.close_rounded, size: 20, color: _kWhite87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kPanelAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: onSearch,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '음식점, 관광지, 백화점 검색',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: Colors.white38, fontWeight: FontWeight.w400),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _kWhite45),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded, size: 18, color: _kWhite45),
                            onPressed: () => onSearch(searchController.text),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03C75A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NAVER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF03C75A),
                          letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => onCategoryTap(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : _kPanelAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.black87 : const Color(0xFFAEAEB2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Map legend ────────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kPanel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(color: Color(0xFF03C75A), label: '장소'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFFFAB00), label: '⭐ 추천'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kWhite87)),
      ],
    );
  }
}
