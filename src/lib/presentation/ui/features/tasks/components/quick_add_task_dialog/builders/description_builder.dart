import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Builds the description content for quick add task dialog
class DescriptionBuilder {
  static Widget buildContent({
    required BuildContext context,
    required String description,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required VoidCallback onDone,
    bool isBottomSheet = false,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        // Description Title with close button
        Row(
          children: [
            Icon(
              Icons.description,
              size: isBottomSheet ? 16 : 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                translationService.translate(TaskTranslationKeys.descriptionLabel),
                style: isBottomSheet
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        )
                    : Theme.of(context).textTheme.titleMedium?.copyWith(
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
        // Description Input
        TextField(
          controller: TextEditingController(text: description),
          onChanged: onChanged,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: translationService.translate(TaskTranslationKeys.addDescriptionHint),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
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

  /// Builds a simple description input field
  static Widget buildSimpleInput({
    required BuildContext context,
    required String description,
    required ValueChanged<String> onChanged,
    VoidCallback? onClear,
    bool showClearButton = true,
    int maxLines = 2,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return TextField(
      controller: TextEditingController(text: description),
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: translationService.translate(TaskTranslationKeys.addDescriptionHint),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(12),
        suffixIcon: showClearButton && description.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 16),
                onPressed: onClear,
                tooltip: translationService.translate(SharedTranslationKeys.clearButton),
              )
            : null,
      ),
    );
  }
}
