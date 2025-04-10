import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskFilters extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Selected start date for filtering
  final DateTime? selectedStartDate;

  /// Selected end date for filtering
  final DateTime? selectedEndDate;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>)? onTagFilterChange;

  /// Callback when date filter changes
  final Function(DateTime?, DateTime?)? onDateFilterChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the date filter button
  final bool showDateFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the completed tasks toggle button
  final bool showCompletedTasksToggle;

  /// Current state of completed tasks toggle
  final bool showCompletedTasks;

  /// Callback when completed tasks toggle changes
  final Function(bool)? onCompletedTasksToggle;

  /// Whether there are items to filter
  final bool hasItems;

  const TaskFilters({
    super.key,
    this.selectedTagIds,
    this.selectedStartDate,
    this.selectedEndDate,
    this.onTagFilterChange,
    this.onDateFilterChange,
    this.onSearchChange,
    this.showTagFilter = true,
    this.showDateFilter = true,
    this.showSearchFilter = true,
    this.showCompletedTasksToggle = true,
    this.showCompletedTasks = false,
    this.onCompletedTasksToggle,
    this.hasItems = true,
  });

  @override
  State<TaskFilters> createState() => _TaskFiltersState();
}

class _TaskFiltersState extends State<TaskFilters> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final iconSize = AppTheme.iconSizeMedium;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showDateFilter && widget.onDateFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showCompletedTasksToggle && widget.onCompletedTasksToggle != null && widget.hasItems));

    // If no filters to show, don't render anything
    if (!showAnyFilters) return const SizedBox.shrink();

    return Row(
      children: [
        // Left side filters (scrollable)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Tag filter
                if (widget.showTagFilter && widget.onTagFilterChange != null)
                  TagSelectDropdown(
                    isMultiSelect: true,
                    onTagsSelected: widget.onTagFilterChange!,
                    icon: TaskUiConstants.tagsIcon,
                    iconSize: iconSize,
                    color: widget.selectedTagIds?.isNotEmpty ?? false ? primaryColor : Colors.grey,
                    tooltip: _translationService.translate(TaskTranslationKeys.filterByTagsTooltip),
                    showLength: true,
                  ),

                // Date filter
                if (widget.showDateFilter && widget.onDateFilterChange != null)
                  DateRangeFilter(
                    selectedStartDate: widget.selectedStartDate,
                    selectedEndDate: widget.selectedEndDate,
                    onDateFilterChange: widget.onDateFilterChange!,
                    iconSize: iconSize,
                    iconColor: Colors.grey,
                  ),

                // Search filter
                if (widget.showSearchFilter && widget.onSearchChange != null)
                  SearchFilter(
                    onSearch: widget.onSearchChange!,
                    placeholder: _translationService.translate(TaskTranslationKeys.searchTasksPlaceholder),
                    iconSize: iconSize,
                    iconColor: Colors.grey,
                    expandedWidth: 200,
                  ),
              ],
            ),
          ),
        ),

        // Right side - Completed tasks toggle button
        if (widget.showCompletedTasksToggle && widget.onCompletedTasksToggle != null && widget.hasItems)
          Container(
            margin: const EdgeInsets.only(left: AppTheme.sizeSmall),
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: _translationService.translate(TaskTranslationKeys.showCompletedTasksTooltip),
                child: InkWell(
                  onTap: () => widget.onCompletedTasksToggle!(!widget.showCompletedTasks),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      widget.showCompletedTasks ? Icons.check_circle : Icons.check_circle_outline,
                      color: widget.showCompletedTasks
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
