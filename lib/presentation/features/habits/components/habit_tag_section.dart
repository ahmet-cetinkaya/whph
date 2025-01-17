import 'package:flutter/material.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

class HabitTagSection extends StatelessWidget {
  final GetListHabitTagsQueryResponse habitTags;
  final Function(List<String>) onTagsSelected;
  final Function(String) onRemoveTag;

  const HabitTagSection({
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
          habitTags.items.map((tag) => Tag(id: tag.tagId, name: tag.tagName, createdDate: DateTime.now())).toList(),
      icon: Icons.add,
    );
  }

  Widget _buildTagChip(HabitTagListItem habitTag) {
    return Chip(
      label: Text(
        habitTag.tagName,
        style: TextStyle(
          color: habitTag.tagColor != null ? Color(int.parse('FF${habitTag.tagColor}', radix: 16)) : null,
        ),
      ),
      onDeleted: () => onRemoveTag(habitTag.id),
    );
  }
}
