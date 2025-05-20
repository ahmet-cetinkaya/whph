import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

class TaskFilters extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Selected start date for filtering
  final DateTime? selectedStartDate;

  /// Selected end date for filtering
  final DateTime? selectedEndDate;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

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
    this.showNoTagsFilter = false,
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
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String? query) {
    _searchDebounce?.cancel();

    // If query is null or empty, immediately call the callback
    if (query == null || query.isEmpty) {
      widget.onSearchChange?.call(query);
      return;
    }

    // For single character searches, use a shorter debounce time
    final debounceTime = query.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500);

    _searchDebounce = Timer(debounceTime, () {
      widget.onSearchChange?.call(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showDateFilter && widget.onDateFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showCompletedTasksToggle && widget.onCompletedTasksToggle != null && widget.hasItems));

    // If no filters to show, don't render anything
    if (!showAnyFilters) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tag filter
                  if (widget.showTagFilter && widget.onTagFilterChange != null)
                    TagSelectDropdown(
                      isMultiSelect: true, // Back to multi-select mode
                      onTagsSelected: (tags, isNoneSelected) {
                        widget.onTagFilterChange!(tags, isNoneSelected);
                      },
                      icon: TagUiConstants.tagIcon,
                      iconSize: AppTheme.iconSizeMedium,
                      color: (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter
                          ? primaryColor
                          : Colors.grey,
                      tooltip: _translationService.translate(TaskTranslationKeys.filterByTagsTooltip),
                      showLength: true,
                      showNoneOption: true,
                      initialSelectedTags: widget.selectedTagIds != null
                          ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                          : [],
                    ),

                  // Date filter
                  if (widget.showDateFilter && widget.onDateFilterChange != null)
                    DateRangeFilter(
                      selectedStartDate: widget.selectedStartDate,
                      selectedEndDate: widget.selectedEndDate,
                      onDateFilterChange: widget.onDateFilterChange!,
                      iconColor: Colors.grey,
                    ),

                  // Search filter
                  if (widget.showSearchFilter && widget.onSearchChange != null)
                    SearchFilter(
                      onSearch: _onSearchChanged,
                      placeholder: _translationService.translate(TaskTranslationKeys.searchTasksPlaceholder),
                      iconSize: AppTheme.iconSizeMedium,
                      iconColor: Colors.grey,
                      expandedWidth: 200,
                    ),

                  // Completed tasks toggle button
                  if (widget.showCompletedTasksToggle && widget.onCompletedTasksToggle != null && widget.hasItems)
                    FilterIconButton(
                      icon: widget.showCompletedTasks ? Icons.check_circle : Icons.check_circle_outline,
                      iconSize: AppTheme.iconSizeMedium,
                      color: widget.showCompletedTasks
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      tooltip: _translationService.translate(TaskTranslationKeys.showCompletedTasksTooltip),
                      onPressed: () {
                        final newState = !widget.showCompletedTasks;
                        widget.onCompletedTasksToggle!(newState);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
