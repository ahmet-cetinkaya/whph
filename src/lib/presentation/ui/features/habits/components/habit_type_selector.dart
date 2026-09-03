import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Segmented control that selects whether a habit is one to build (good) or to
/// break (bad). Archived habits render the control read-only.
class HabitTypeSelector extends StatelessWidget {
  final HabitType type;
  final ValueChanged<HabitType> onChanged;
  final bool isReadOnly;
  final ITranslationService translationService;

  const HabitTypeSelector({
    super.key,
    required this.type,
    required this.onChanged,
    required this.translationService,
    this.isReadOnly = false,
  });

  static const Map<HabitType, ({String labelKey, IconData icon})> _options = {
    HabitType.good: (labelKey: HabitTranslationKeys.typeGood, icon: Icons.trending_up),
    HabitType.bad: (labelKey: HabitTranslationKeys.typeBad, icon: Icons.block),
  };

  void _handleSelection(Set<HabitType> selection) {
    final selected = selection.first;
    if (selected == type) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: translationService.translate(HabitTranslationKeys.habitTypeHint),
      readOnly: isReadOnly,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.size2XSmall),
        child: SegmentedButton<HabitType>(
          segments: [
            for (final entry in _options.entries)
              ButtonSegment<HabitType>(
                value: entry.key,
                icon: Icon(entry.value.icon),
                label: Text(translationService.translate(entry.value.labelKey)),
              ),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: isReadOnly ? null : _handleSelection,
        ),
      ),
    );
  }
}
