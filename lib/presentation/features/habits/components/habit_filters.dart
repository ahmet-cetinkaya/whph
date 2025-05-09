import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitFilters extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool) onTagFilterChange;

  /// Whether to show the tag filter
  final bool showTagFilter;

  const HabitFilters({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    required this.onTagFilterChange,
    this.showTagFilter = true,
  });

  @override
  State<HabitFilters> createState() => _HabitFiltersState();
}

class _HabitFiltersState extends State<HabitFilters> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    if (!widget.showTagFilter) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter by tags
          TagSelectDropdown(
            isMultiSelect: true,
            onTagsSelected: (tags, isNoneSelected) => widget.onTagFilterChange(tags, isNoneSelected),
            icon: Icons.label,
            iconSize: AppTheme.iconSizeMedium,
            color: (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter
                ? AppTheme.primaryColor
                : Colors.grey,
            tooltip: _translationService.translate(HabitTranslationKeys.filterByTagsTooltip),
            showLength: true,
            showNoneOption: true,
            initialSelectedTags: widget.selectedTagIds != null
                ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                : [],
          ),
        ],
      ),
    );
  }
}
