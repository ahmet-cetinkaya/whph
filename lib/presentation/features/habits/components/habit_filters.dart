import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitFilters extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Flag to indicate if archived habits should be shown
  final bool filterByArchived;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when archive filter changes
  final Function(bool)? onArchiveFilterChange;

  /// Whether to show the tag filter
  final bool showTagFilter;

  /// Whether to show the archive filter
  final bool showArchiveFilter;

  const HabitFilters({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.filterByArchived = false,
    this.onTagFilterChange,
    this.onArchiveFilterChange,
    this.showTagFilter = true,
    this.showArchiveFilter = true,
  });

  @override
  State<HabitFilters> createState() => _HabitFiltersState();
}

class _HabitFiltersState extends State<HabitFilters> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    if (!widget.showTagFilter && !widget.showArchiveFilter) {
      return const SizedBox.shrink();
    }

    final primaryColor = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter by tags
          if (widget.showTagFilter)
            TagSelectDropdown(
              isMultiSelect: true,
              onTagsSelected: (tags, isNoneSelected) => widget.onTagFilterChange?.call(tags, isNoneSelected),
              icon: Icons.label,
              iconSize: AppTheme.iconSizeMedium,
              color:
                  (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter ? primaryColor : Colors.grey,
              tooltip: _translationService.translate(HabitTranslationKeys.filterByTagsTooltip),
              showLength: true,
              showNoneOption: true,
              initialSelectedTags: widget.selectedTagIds != null
                  ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                  : [],
            ),

          // Archive filter
          if (widget.showArchiveFilter)
            FilterIconButton(
              icon: widget.filterByArchived ? Icons.archive : Icons.archive_outlined,
              iconSize: AppTheme.iconSizeMedium,
              color: widget.filterByArchived ? primaryColor : Colors.grey,
              tooltip: _translationService.translate(
                widget.filterByArchived ? HabitTranslationKeys.hideArchived : HabitTranslationKeys.showArchived,
              ),
              onPressed: () => widget.onArchiveFilterChange?.call(!widget.filterByArchived),
            ),
        ],
      ),
    );
  }
}
