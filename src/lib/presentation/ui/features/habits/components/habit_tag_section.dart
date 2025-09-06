import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitTagSection extends StatefulWidget {
  final GetListHabitTagsQueryResponse habitTags;
  final Function(List<DropdownOption<String>>) onTagsSelected;
  final Function(String) onRemoveTag;

  const HabitTagSection({
    super.key,
    required this.habitTags,
    required this.onTagsSelected,
    required this.onRemoveTag,
  });

  @override
  State<HabitTagSection> createState() => _HabitTagSectionState();
}

class _HabitTagSectionState extends State<HabitTagSection> {
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
  }

  void _removeEventListeners() {
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
  }

  void _handleHabitUpdated() {
    if (!mounted) return;
    setState(() {});
  }

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
            ...widget.habitTags.items.map(_buildTagChip),
          ],
        ),
      ],
    );
  }

  Widget _buildTagDropdown() {
    return TagSelectDropdown(
      key: ValueKey(widget.habitTags.items.length),
      isMultiSelect: true,
      onTagsSelected: (selected, _) {
        widget.onTagsSelected(selected);
        _habitsService.notifyHabitUpdated(widget.habitTags.items.first.habitId);
      },
      initialSelectedTags: widget.habitTags.items
          .map((tag) => DropdownOption<String>(
              value: tag.tagId,
              label:
                  tag.tagName.isNotEmpty ? tag.tagName : _translationService.translate(SharedTranslationKeys.untitled)))
          .toList(),
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
      onDeleted: () {
        widget.onRemoveTag(habitTag.id);
        _habitsService.notifyHabitUpdated(habitTag.habitId);
      },
      deleteIcon: Icon(SharedUiConstants.closeIcon, size: AppTheme.iconSizeSmall),
    );
  }
}
