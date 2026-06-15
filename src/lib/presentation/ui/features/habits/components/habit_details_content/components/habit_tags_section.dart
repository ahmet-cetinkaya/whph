import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the tags section for habit details.
class HabitTagsSection {
  final ITranslationService translationService;
  final GetListHabitTagsQueryResponse? habitTags;
  final Function(List<DropdownOption<String>> options) onTagsSelected;
  final bool autoOpenDropdown;

  const HabitTagsSection({
    required this.translationService,
    required this.habitTags,
    required this.onTagsSelected,
    this.autoOpenDropdown = false,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(HabitTranslationKeys.tagsLabel),
        icon: TagUiConstants.tagIcon,
        widget: TagSelectDropdown(
          key: ValueKey('habit_tags'),
          isMultiSelect: true,
          onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => onTagsSelected(tagOptions),
          autoOpen: autoOpenDropdown,
          showSelectedInDropdown: true,
          initialSelectedTags: habitTags?.items
                  .map((tag) => DropdownOption<String>(
                      value: tag.tagId,
                      label: tag.tagName.isNotEmpty
                          ? tag.tagName
                          : translationService.translate(SharedTranslationKeys.untitled)))
                  .toList() ??
              [],
          icon: SharedUiConstants.addIcon,
          iconSize: AppTheme.iconSizeMedium,
        ),
      );
}
