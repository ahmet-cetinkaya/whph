import 'package:flutter/material.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/shared/components/detail_table.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Builds the parent task section for task details.
class TaskParentSection {
  final ITranslationService translationService;
  final String? parentTitle;
  final VoidCallback onTap;

  const TaskParentSection({
    required this.translationService,
    required this.parentTitle,
    required this.onTap,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.parentTaskLabel),
        icon: TaskUiConstants.parentTaskIcon,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    parentTitle ?? '',
                    style: AppTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.open_in_new, size: AppTheme.iconSizeSmall, color: AppTheme.secondaryTextColor),
              ],
            ),
          ),
        ),
      );
}
