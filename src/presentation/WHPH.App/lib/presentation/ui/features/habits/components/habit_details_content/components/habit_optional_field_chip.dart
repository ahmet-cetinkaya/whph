import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'habit_field_helpers.dart';

/// Builds the optional field chip for habit details.
class HabitOptionalFieldChip {
  static Widget build({
    required BuildContext context,
    required String fieldKey,
    required bool isSelected,
    required bool hasContent,
    required ITranslationService translationService,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(HabitFieldHelpers.getFieldLabel(fieldKey, translationService)),
          const SizedBox(width: 4),
          Icon(Icons.add, size: AppTheme.iconSizeSmall),
        ],
      ),
      avatar: Icon(
        HabitFieldHelpers.getFieldIcon(fieldKey),
        size: AppTheme.iconSizeSmall,
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: hasContent ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : null,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}
