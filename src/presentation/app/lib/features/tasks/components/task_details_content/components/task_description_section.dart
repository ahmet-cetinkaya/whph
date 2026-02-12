import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show MarkdownEditor;
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/shared/components/detail_table.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';

/// Builds the description section for task details.
class TaskDescriptionSection {
  final ITranslationService translationService;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function(String) onChanged;

  const TaskDescriptionSection({
    required this.translationService,
    required this.controller,
    this.focusNode,
    required this.onChanged,
  });

  Widget build(BuildContext context) => DetailTable(
        forceVertical: true,
        rowData: [
          DetailTableRowData(
            label: translationService.translate(TaskTranslationKeys.descriptionLabel),
            icon: TaskUiConstants.descriptionIcon,
            widget: MarkdownEditor.simple(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              height: 250,
              style: Theme.of(context).textTheme.bodyMedium,
              hintText: translationService.translate(SharedTranslationKeys.markdownEditorHint),
              translations: SharedTranslationKeys.mapMarkdownTranslations(translationService),
            ),
            removePadding: true,
          ),
        ],
        isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
      );
}
