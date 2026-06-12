import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/estimated_time_input.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Builds the estimated time content for quick add task dialog
class EstimatedTimeBuilder {
  static Widget buildContent({
    required BuildContext context,
    required int? estimatedTime,
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
        EstimatedTimeInput(
          totalMinutes: estimatedTime ?? 0,
          onValueChanged: onValueChanged,
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
}
