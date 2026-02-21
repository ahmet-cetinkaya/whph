import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show NumericInput;
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Builds the estimated time content for quick add task dialog
class EstimatedTimeBuilder {
  static Widget buildContent({
    required BuildContext context,
    required int? estimatedTime,
    required bool isEstimatedTimeExplicitlySet,
    required ValueChanged<int> onValueChanged,
    required VoidCallback onClear,
    required VoidCallback onDone,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 8,
        ),
        // Estimated Time Icon with status
        Row(
          children: [
            Icon(
              TaskUiConstants.estimatedTimeIcon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: onDone,
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Estimated Time Input
        NumericInput(
          initialValue: estimatedTime ?? 0,
          minValue: 0,
          maxValue: 480, // 8 hours maximum
          incrementValue: 10,
          decrementValue: 10,
          onValueChanged: onValueChanged,
          valueSuffix: translationService.translate(SharedTranslationKeys.minutesShort),
          iconSize: 20,
        ),
        SizedBox(height: 16),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onClear,
              child: Text(translationService.translate(SharedTranslationKeys.clearButton)),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: onDone,
              child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds estimated time icon with status
  static Widget buildIcon({
    required BuildContext context,
    int? estimatedTime,
    bool isEstimatedTimeExplicitlySet = false,
  }) {
    if (estimatedTime != null && estimatedTime > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isEstimatedTimeExplicitlySet
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          estimatedTime.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isEstimatedTimeExplicitlySet
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
        ),
      );
    } else {
      return Icon(
        TaskUiConstants.estimatedTimeIcon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }
  }

  /// Builds a simple estimated time input field
  static Widget buildSimpleInput({
    required BuildContext context,
    required int? estimatedTime,
    required ValueChanged<int> onValueChanged,
    VoidCallback? onClear,
    bool showClearButton = true,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return NumericInput(
      initialValue: estimatedTime ?? 0,
      minValue: 0,
      maxValue: 480, // 8 hours maximum
      incrementValue: 5,
      decrementValue: 5,
      onValueChanged: onValueChanged,
      valueSuffix: translationService.translate(SharedTranslationKeys.minutesShort),
      iconSize: 20,
    );
  }
}
