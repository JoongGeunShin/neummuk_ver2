import 'package:flutter/material.dart';
import '../../core/constants/region_data.dart';
import '../../core/utils/context_ext.dart';

/// 지역 선택 위젯.
/// [value]: 현재 선택된 지역 리스트 (예: ['전체'], ['서울', '경기/성남시'])
/// [onChanged]: 변경 시 호출되는 콜백
class RegionSelector extends StatefulWidget {
  const RegionSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  // province → null(전체) or Set<city>
  late Map<String, Set<String>?> _sel;

  @override
  void initState() {
    super.initState();
    _sel = RegionData.fromList(widget.value);
  }

  bool _isProvinceActive(String p) => _sel.containsKey(p);

  bool _isCityActive(String province, String city) =>
      _sel[province]?.contains(city) ?? false;

  bool get _isAll => _sel.isEmpty;

  void _tapAll() {
    setState(() => _sel = {});
    widget.onChanged(['전체']);
  }

  void _tapProvince(String province) {
    setState(() {
      if (_sel.containsKey(province)) {
        // 이미 선택된 도: 전체 해제 (도 + 시군 모두 제거)
        _sel.remove(province);
      } else {
        // 새로 선택: 전도 선택(null)
        _sel[province] = null;
      }
    });
    widget.onChanged(RegionData.toList(_sel));
  }

  void _tapCity(String province, String city) {
    setState(() {
      final current = _sel[province];
      if (current == null) {
        // 도 전체 선택 → 특정 시군으로 전환
        _sel[province] = {city};
      } else if (current.contains(city)) {
        // 이미 선택된 시군: 해제
        current.remove(city);
        if (current.isEmpty) {
          // 시군이 모두 해제되면 도도 해제
          _sel.remove(province);
        }
      } else {
        current.add(city);
      }
    });
    widget.onChanged(RegionData.toList(_sel));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // 시/군 표시가 필요한 활성 도 목록
    final activeDosWithCities = RegionData.provinces
        .where((p) => _sel.containsKey(p))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 전체 ────────────────────────────────────────────
        GestureDetector(
          onTap: _tapAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _isAll ? c.primary : c.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _isAll ? c.primary : c.outline,
                  width: _isAll ? 0 : 1),
            ),
            child: Text(
              '전체',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isAll ? c.onPrimary : c.textMuted,
              ),
            ),
          ),
        ),

        SizedBox(height: context.hp(2)),

        // ── 특별시 · 광역시 ────────────────────────────────
        Text('특별시 · 광역시',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textFaint)),
        SizedBox(height: context.hp(0.8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RegionData.metros.map((p) {
            final on = _isProvinceActive(p);
            return GestureDetector(
              onTap: () => _tapProvince(p),
              child: _ProvinceChip(label: p, active: on, c: c),
            );
          }).toList(),
        ),

        SizedBox(height: context.hp(2)),

        // ── 도 ──────────────────────────────────────────────
        Text('도',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textFaint)),
        SizedBox(height: context.hp(0.8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RegionData.provinces.map((p) {
            final on = _isProvinceActive(p);
            return GestureDetector(
              onTap: () => _tapProvince(p),
              child: _ProvinceChip(
                label: p,
                active: on,
                hasSub: true,
                // 도 전체 선택 vs 시군 일부 선택 구분 표시
                partial: on && _sel[p] != null && _sel[p]!.isNotEmpty,
                c: c,
              ),
            );
          }).toList(),
        ),

        // ── 활성 도의 시/군 ────────────────────────────────
        if (activeDosWithCities.isNotEmpty) ...[
          SizedBox(height: context.hp(2)),
          ...activeDosWithCities.map((province) {
            final cities = RegionData.getCities(province) ?? [];
            // 도 전체 선택이면 시군 선택 불필요 안내
            final isWholeProvince = _sel[province] == null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$province 시/군',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.primary)),
                    const SizedBox(width: 6),
                    if (isWholeProvince)
                      Text('(전체 선택됨)',
                          style: TextStyle(fontSize: 11, color: c.textFaint))
                    else
                      GestureDetector(
                        onTap: () {
                          setState(() => _sel[province] = null);
                          widget.onChanged(RegionData.toList(_sel));
                        },
                        child: Text('전체 선택',
                            style: TextStyle(
                                fontSize: 11,
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: c.primary)),
                      ),
                  ],
                ),
                SizedBox(height: context.hp(0.8)),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: cities.map((city) {
                    final on = !isWholeProvince && _isCityActive(province, city);
                    return GestureDetector(
                      onTap: () => _tapCity(province, city),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWholeProvince
                              ? c.primarySoft
                              : (on ? c.primarySoft : c.surface),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isWholeProvince
                                ? c.primary.withValues(alpha: 0.4)
                                : (on ? c.primary : c.outline),
                            width: on || isWholeProvince ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          city,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (on || isWholeProvince)
                                ? c.primary
                                : c.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: context.hp(1.5)),
              ],
            );
          }),
        ],
      ],
    );
  }
}

class _ProvinceChip extends StatelessWidget {
  const _ProvinceChip({
    required this.label,
    required this.active,
    required this.c,
    this.hasSub = false,
    this.partial = false,
  });

  final String label;
  final bool active;
  final bool hasSub;
  final bool partial; // 일부 시군만 선택
  final dynamic c;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active ? c.primarySoft : c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? c.primary : c.outline,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? c.primary : c.textMuted,
            ),
          ),
          if (hasSub && active) ...[
            const SizedBox(width: 3),
            Icon(
              partial
                  ? Icons.tune_rounded
                  : Icons.check_rounded,
              size: 13,
              color: c.primary,
            ),
          ],
        ],
      ),
    );
  }
}
