import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_ext.dart';
import '../../domain/entities/food_catalog_entity.dart';
import '../providers/explore_provider.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

class AddFoodDialog extends ConsumerWidget {
  const AddFoodDialog({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(exploreProvider);
    final notifier = ref.read(exploreProvider.notifier);

    final screenH = MediaQuery.of(context).size.height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final listMaxH = (screenH - keyboardH - 120 - 80).clamp(
      80.0,
      screenH * 0.4,
    );

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"$query" 검색 결과',
                        style: AppTypography.bodyLg.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '추가할 음식을 선택하세요',
                        style: AppTypography.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    notifier.clearApiCandidates();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.close_rounded, color: c.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.isLoadingCandidates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: c.primary),
                ),
              )
            else if (state.apiCandidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '요청하신 음식의 결과를 찾지 못했어요\n올바른 이름 또는 구체적으로 입력해주세요',
                    style: AppTypography.label.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              AbsorbPointer(
                absorbing: state.isSaving,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listMaxH),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.apiCandidates.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.outline),
                    itemBuilder: (ctx, i) {
                      final food = state.apiCandidates[i];
                      final isSavingThis =
                          state.savingCanonicalName == food.canonicalName;
                      return _CandidateTile(
                        food: food,
                        isSaving: isSavingThis,
                        onTap: state.isSaving
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                final ok = await notifier.saveSelectedFood(
                                  food,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? '"${food.displayName}" 추가됨'
                                            : '추가에 실패했어요',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.food,
    required this.onTap,
    this.isSaving = false,
  });

  final FoodCatalogEntity food;
  final VoidCallback? onTap;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isSaving ? 1.0 : (onTap == null ? 0.5 : 1.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        )
                      : Text(
                          food.emoji,
                          style: AppTypography.titleSm.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.displayName,
                      style: AppTypography.bodyMute.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          food.category,
                          style: AppTypography.tiny.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                        Text(
                          '  ·  ',
                          style: AppTypography.tiny.copyWith(
                            fontWeight: FontWeight.w400,
                            color: c.textFaint,
                          ),
                        ),
                        Text(
                          '1인분 ${food.nutrition.servingSizeG.round()}g',
                          style: AppTypography.tiny.copyWith(
                            color: c.textFaint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${food.nutrition.caloriesKcal.round()}',
                    style: AppTypography.bodyLg.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: AppTypography.micro.copyWith(color: c.textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.add_circle_outline_rounded,
                color: c.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
