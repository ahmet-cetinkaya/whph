import 'package:flutter/material.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class HabitTagSection extends StatelessWidget {
  final GetListHabitTagsQueryResponse habitTags;
  final Function(List<DropdownOption<String>>) onTagsSelected;
  final Function(String) onRemoveTag;
  final _translationService = container.resolve<ITranslationService>();

  HabitTagSection({
    super.key,
    required this.habitTags,
    required this.onTagsSelected,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            _buildTagDropdown(),
            ...habitTags.items.map(_buildTagChip),
          ],
        ),
      ],
    );
  }

  Widget _buildTagDropdown() {
    return TagSelectDropdown(
      key: ValueKey(habitTags.items.length),
      isMultiSelect: true,
      onTagsSelected: onTagsSelected,
      initialSelectedTags:
          habitTags.items.map((tag) => DropdownOption<String>(value: tag.tagId, label: tag.tagName)).toList(),
      icon: SharedUiConstants.addIcon,
      tooltip: _translationService.translate(HabitTranslationKeys.selectTagsTooltip),
    );
  }

  Widget _buildTagChip(HabitTagListItem habitTag) {
    final tagColor =
        habitTag.tagColor != null ? Color(int.parse('FF${habitTag.tagColor}', radix: 16)) : AppTheme.disabledColor;

    return Chip(
      label: Text(
        habitTag.tagName,
        style: AppTheme.bodySmall.copyWith(color: tagColor),
      ),
      onDeleted: () => onRemoveTag(habitTag.id),
      deleteIcon: Icon(SharedUiConstants.closeIcon, size: AppTheme.iconSizeSmall),
    );
  }
}
