import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the tags section for task details.
class TaskTagsSection {
  final ITranslationService translationService;
  final GetListTaskTagsQueryResponse taskTags;
  final void Function(List<DropdownOption<String>> options) onTagsSelected;

  const TaskTagsSection({
    required this.translationService,
    required this.taskTags,
    required this.onTagsSelected,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.tagsLabel),
        icon: TagUiConstants.tagIcon,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: TagSelectDropdown(
            key: ValueKey(taskTags.items.length),
            isMultiSelect: true,
            onTagsSelected: (options, _) => onTagsSelected(options),
            showSelectedInDropdown: true,
            initialSelectedTags: taskTags.items
                .map((tag) => DropdownOption<String>(
                    label: tag.tagName.isNotEmpty
                        ? tag.tagName
                        : translationService.translate(SharedTranslationKeys.untitled),
                    value: tag.tagId))
                .toList(),
            icon: SharedUiConstants.addIcon,
          ),
        ),
      );
}
