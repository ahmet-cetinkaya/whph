import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'dart:async';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_list_option_settings.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/date_range_filter.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/ui/shared/components/save_button.dart';
import 'package:whph/presentation/ui/shared/components/search_filter.dart';
import 'package:whph/presentation/ui/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/ui/shared/components/group_dialog_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';

class TaskListOptions extends PersistentListOptionsBase {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Selected start date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedStartDate;

  /// Selected end date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedEndDate;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<TaskSortFields>? sortConfig;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when date filter changes
  final Function(DateTime?, DateTime?)? onDateFilterChange;

  /// Callback when date filter setting changes (with quick selection support)
  final Function(DateFilterSetting?)? onDateFilterSettingChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Callback when sort changes
  final Function(SortConfig<TaskSortFields>)? onSortChange;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the date filter button
  final bool showDateFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the sort button
  final bool showSortButton;

  /// Whether to show the layout toggle button when custom sort is enabled
  final bool showLayoutToggle;

  /// Whether to force the original layout even with custom sort
  final bool forceOriginalLayout;

  /// Callback when layout toggle changes
  final Function(bool)? onLayoutToggleChange;

  /// Whether to show the completed tasks toggle button
  final bool showCompletedTasksToggle;

  /// Current state of completed tasks toggle
  final bool showCompletedTasks;

  /// Callback when completed tasks toggle changes
  final Function(bool)? onCompletedTasksToggle;

  /// Whether there are items to filter
  final bool hasItems;

  /// Whether to show the subtasks toggle button
  final bool showSubTasksToggle;

  /// Current state of subtasks toggle
  final bool showSubTasks;

  /// Callback when subtasks toggle changes
  final Function(bool)? onSubTasksToggle;

  /// Whether to show the grouping option
  final bool showGroupingOption;

  const TaskListOptions({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.dateFilterSetting,
    this.selectedStartDate,
    this.selectedEndDate,
    this.search,
    this.sortConfig,
    this.onTagFilterChange,
    this.onDateFilterChange,
    this.onDateFilterSettingChange,
    this.onSearchChange,
    this.onSortChange,
    super.onSaveSettings,
    this.showTagFilter = true,
    this.showDateFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    this.showLayoutToggle = true,
    this.showGroupingOption = true,
    this.forceOriginalLayout = false,
    this.onLayoutToggleChange,
    super.showSaveButton = true,
    this.showCompletedTasksToggle = true,
    this.showCompletedTasks = false,
    this.onCompletedTasksToggle,
    this.showSubTasksToggle = true,
    this.showSubTasks = false,
    this.onSubTasksToggle,
    this.hasItems = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
    super.onSettingsLoaded,
  });

  @override
  State<TaskListOptions> createState() => _TaskListOptionsState();
}

class _TaskListOptionsState extends PersistentListOptionsBaseState<TaskListOptions> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? "${SettingKeys.tasksListOptionsSettings}_${widget.settingKeyVariantSuffix}"
        : SettingKeys.tasksListOptionsSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    // Set loading flag to prevent didUpdateWidget from triggering unsaved changes
    setState(() {
      isLoadingSettings = true;
    });

    final savedSettings = await filterSettingsManager.loadFilterSettings(
      settingKey: settingKey,
    );

    if (savedSettings != null) {
      final filterSettings = TaskListOptionSettings.fromJson(savedSettings);

      setState(() {
        lastSearchQuery = filterSettings.search;
      });

      if (widget.onTagFilterChange != null) {
        final tagIds = filterSettings.selectedTagIds ?? [];
        final showNoTags = filterSettings.showNoTagsFilter;

        widget.onTagFilterChange!(
          tagIds.map((id) => DropdownOption<String>(value: id, label: id)).toList(),
          showNoTags,
        );
      }

      if (widget.onDateFilterChange != null || widget.onDateFilterSettingChange != null) {
        final dateFilterSetting = filterSettings.dateFilterSetting;

        if (dateFilterSetting != null) {
          // Calculate current dates for quick selections or use static dates for manual selections
          final currentRange = dateFilterSetting.calculateCurrentDateRange();

          widget.onDateFilterChange?.call(currentRange.startDate, currentRange.endDate);
          widget.onDateFilterSettingChange?.call(dateFilterSetting);
        } else {
          // Fallback to legacy dates for backward compatibility
          widget.onDateFilterChange?.call(
            filterSettings.selectedStartDate,
            filterSettings.selectedEndDate,
          );
          widget.onDateFilterSettingChange?.call(null);
        }
      }

      if (widget.onSearchChange != null && filterSettings.search != null) {
        widget.onSearchChange!(filterSettings.search);
      }

      if (widget.onCompletedTasksToggle != null) {
        widget.onCompletedTasksToggle!(filterSettings.showCompletedTasks);
      }

      if (widget.onSubTasksToggle != null) {
        widget.onSubTasksToggle!(filterSettings.showSubTasks);
      }

      if (widget.onSortChange != null && filterSettings.sortConfig != null) {
        widget.onSortChange!(filterSettings.sortConfig!);
      }

      if (widget.onLayoutToggleChange != null) {
        widget.onLayoutToggleChange!(filterSettings.forceOriginalLayout);
      }
    }

    if (mounted) {
      setState(() {
        isSettingLoaded = true;
        isLoadingSettings = false;
        // Clear unsaved changes after loading saved settings
        hasUnsavedChanges = false;
      });

      // Ensure unsaved changes are cleared after all callbacks are processed
      // Use microtask to run after current event loop
      Future.microtask(() {
        if (mounted) {
          setState(() {
            hasUnsavedChanges = false;
          });
        }
      });
    }
    widget.onSettingsLoaded?.call();
  }

  @override
  Future<void> saveFilterSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {
        // For auto-refresh quick selections, ignore selectedStartDate/selectedEndDate
        // since they are dynamically calculated and shouldn't be saved
        final isAutoRefreshSelection = widget.dateFilterSetting?.isQuickSelection == true &&
            widget.dateFilterSetting?.isAutoRefreshEnabled == true;

        final settings = TaskListOptionSettings(
          selectedTagIds: widget.selectedTagIds,
          showNoTagsFilter: widget.showNoTagsFilter,
          dateFilterSetting: widget.dateFilterSetting,
          selectedStartDate: isAutoRefreshSelection ? null : widget.selectedStartDate,
          selectedEndDate: isAutoRefreshSelection ? null : widget.selectedEndDate,
          search: lastSearchQuery, // Use lastSearchQuery instead of widget.search
          showCompletedTasks: widget.showCompletedTasks,
          showSubTasks: widget.showSubTasks,
          sortConfig: widget.sortConfig,
          forceOriginalLayout: widget.forceOriginalLayout,
        );

        await filterSettingsManager.saveFilterSettings(
          settingKey: settingKey,
          filterSettings: settings.toJson(),
        );

        if (mounted) {
          setState(() {
            hasUnsavedChanges = false;
          });

          showSavedMessageTemporarily();
        }

        // Notify parent that settings were saved
        widget.onSaveSettings?.call();
      },
    );
  }

  @override
  Future<void> checkForUnsavedChanges() async {
    // For auto-refresh quick selections, ignore selectedStartDate/selectedEndDate
    // since they are dynamically calculated and shouldn't be compared
    final isAutoRefreshSelection =
        widget.dateFilterSetting?.isQuickSelection == true && widget.dateFilterSetting?.isAutoRefreshEnabled == true;

    final currentSettings = TaskListOptionSettings(
      selectedTagIds: widget.selectedTagIds,
      showNoTagsFilter: widget.showNoTagsFilter,
      dateFilterSetting: widget.dateFilterSetting,
      selectedStartDate: isAutoRefreshSelection ? null : widget.selectedStartDate,
      selectedEndDate: isAutoRefreshSelection ? null : widget.selectedEndDate,
      search: lastSearchQuery,
      showCompletedTasks: widget.showCompletedTasks,
      showSubTasks: widget.showSubTasks,
      sortConfig: widget.sortConfig,
      forceOriginalLayout: widget.forceOriginalLayout,
    ).toJson();

    final hasChanges = await filterSettingsManager.hasUnsavedChanges(
      settingKey: settingKey,
      currentSettings: currentSettings,
    );

    if (mounted && hasUnsavedChanges != hasChanges) {
      setState(() {
        hasUnsavedChanges = hasChanges;
      });
    }
  }

  bool _hasFilterChanges(TaskListOptions oldWidget) {
    final tagChanges = widget.selectedTagIds != oldWidget.selectedTagIds;
    final noTagsChanges = widget.showNoTagsFilter != oldWidget.showNoTagsFilter;
    final dateSettingChanges = widget.dateFilterSetting != oldWidget.dateFilterSetting;
    final startDateChanges = widget.selectedStartDate != oldWidget.selectedStartDate;
    final endDateChanges = widget.selectedEndDate != oldWidget.selectedEndDate;
    final completedChanges = widget.showCompletedTasks != oldWidget.showCompletedTasks;
    final subTasksChanges = widget.showSubTasks != oldWidget.showSubTasks;
    final sortChanges = widget.sortConfig != oldWidget.sortConfig;
    final layoutChanges = widget.forceOriginalLayout != oldWidget.forceOriginalLayout;

    final hasNonSearchChanges = tagChanges ||
        noTagsChanges ||
        dateSettingChanges ||
        startDateChanges ||
        endDateChanges ||
        completedChanges ||
        subTasksChanges ||
        sortChanges ||
        layoutChanges;

    if (hasNonSearchChanges) {
      // Don't trigger save button if this is just auto-refresh date recalculation
      final isAutoRefresh = _isClearAutoRefreshDateRecalculation(oldWidget);
      if (isAutoRefresh) {
        return false;
      }

      // REMOVED: _isSettingsLoadingPattern check because it was blocking genuine user interactions
      // The isLoadingSettings flag should be sufficient to prevent false positives during actual loading

      return true;
    }

    return false;
  }

  /// Simple check: Is this just auto-refresh date recalculation?
  bool _isClearAutoRefreshDateRecalculation(TaskListOptions oldWidget) {
    // Only ignore changes if ALL these conditions are met:
    // 1. Both have the exact same auto-refresh quick selection
    // 2. Only the calculated dates (selectedStartDate/selectedEndDate) changed
    // 3. The DateFilterSetting object itself is unchanged (same reference/content)

    final currentAutoRefresh =
        widget.dateFilterSetting?.isQuickSelection == true && widget.dateFilterSetting?.isAutoRefreshEnabled == true;
    final oldAutoRefresh = oldWidget.dateFilterSetting?.isQuickSelection == true &&
        oldWidget.dateFilterSetting?.isAutoRefreshEnabled == true;

    // Both must have auto-refresh enabled
    if (!currentAutoRefresh || !oldAutoRefresh) {
      return false;
    }

    // DateFilterSetting objects must be equal (same settings, just dates recalculated)
    final sameSettings = widget.dateFilterSetting == oldWidget.dateFilterSetting;

    // Only dates should have changed, nothing else
    final onlyDatesChanged = (widget.selectedStartDate != oldWidget.selectedStartDate ||
            widget.selectedEndDate != oldWidget.selectedEndDate) &&
        widget.selectedTagIds == oldWidget.selectedTagIds &&
        widget.showNoTagsFilter == oldWidget.showNoTagsFilter &&
        widget.showCompletedTasks == oldWidget.showCompletedTasks &&
        widget.showSubTasks == oldWidget.showSubTasks &&
        widget.sortConfig == oldWidget.sortConfig;

    final isAutoRefreshRecalc = sameSettings && onlyDatesChanged;

    return isAutoRefreshRecalc;
  }

  bool _hasSearchChanges(TaskListOptions oldWidget) {
    final hasChanges = widget.search != oldWidget.search;
    return hasChanges;
  }

  @override
  void didUpdateWidget(TaskListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Skip change detection while loading settings to prevent false unsaved changes
    if (isLoadingSettings) {
      return;
    }

    final hasFilterChanges = _hasFilterChanges(oldWidget);
    final hasSearchChanges = _hasSearchChanges(oldWidget);
    final isFromSearchCallback = searchDebounce?.isActive == true || searchStateCheckTimer?.isActive == true;

    if (hasFilterChanges || (hasSearchChanges && !isFromSearchCallback)) {
      // Force immediate check for unsaved changes
      Future.microtask(handleFilterChange);
    }
  }

  void _onSearchChanged(String? query) {
    searchDebounce?.cancel();
    searchStateCheckTimer?.cancel();

    lastSearchQuery = query;

    // Since the parent isn't updating its state immediately,
    // we need to force a check for unsaved changes here
    void processSearchChange() {
      if (!mounted) return;

      // Call parent widget's callback
      widget.onSearchChange?.call(query);

      // Force immediate check for unsaved changes
      handleFilterChange();

      // Keep monitoring for state changes to update the UI when parent updates
      searchStateCheckTimer?.cancel();
      searchStateCheckTimer = Timer.periodic(SharedUiConstants.searchDebounceTime, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (widget.search == query) {
          timer.cancel();
          handleFilterChange(); // Check again after state is updated
        } else if (timer.tick >= 50) {
          // Extended to 5 seconds for slower state updates
          timer.cancel();
          handleFilterChange(); // Force one last check
        }
      });
    }

    // Always process search changes immediately now
    processSearchChange();
  }

  @override
  Widget build(BuildContext context) {
    if (!isSettingLoaded) return const SizedBox.shrink();

    return Row(
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
                    key: ValueKey({
                      'showNoTagsFilter': widget.showNoTagsFilter,
                      'selectedTags': widget.selectedTagIds?.join(',') ?? '',
                    }.toString()),
                    isMultiSelect: true,
                    onTagsSelected: (tags, isNoneSelected) {
                      if (mounted) {
                        widget.onTagFilterChange!(tags, isNoneSelected);
                      }
                    },
                    icon: TagUiConstants.tagIcon,
                    iconSize: AppTheme.iconSizeMedium,
                    color: (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter
                        ? _themeService.primaryColor
                        : Colors.grey,
                    tooltip: _translationService.translate(TaskTranslationKeys.filterByTagsTooltip),
                    showLength: true,
                    showNoneOption: true,
                    initialSelectedTags: widget.selectedTagIds != null
                        ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                        : [],
                    initialShowNoTagsFilter: widget.showNoTagsFilter,
                    initialNoneSelected: widget.showNoTagsFilter,
                  ),

                // Date filter
                if (widget.showDateFilter &&
                    (widget.onDateFilterChange != null || widget.onDateFilterSettingChange != null))
                  DateRangeFilter(
                    selectedStartDate: widget.selectedStartDate,
                    selectedEndDate: widget.selectedEndDate,
                    dateFilterSetting: widget.dateFilterSetting,
                    onDateFilterChange: widget.onDateFilterChange ?? (start, end) {},
                    onDateFilterSettingChange: widget.onDateFilterSettingChange,
                    iconColor: (widget.selectedStartDate != null ||
                            widget.selectedEndDate != null ||
                            widget.dateFilterSetting != null)
                        ? _themeService.primaryColor
                        : Colors.grey,
                  ),

                // Search filter
                if (widget.showSearchFilter && widget.onSearchChange != null)
                  SearchFilter(
                    initialValue: lastSearchQuery ?? widget.search,
                    onSearch: _onSearchChanged,
                    placeholder: _translationService.translate(TaskTranslationKeys.searchTasksPlaceholder),
                    iconSize: AppTheme.iconSizeMedium,
                    iconColor: (lastSearchQuery != null && lastSearchQuery!.isNotEmpty)
                        ? _themeService.primaryColor
                        : Colors.grey,
                    expandedWidth: 200,
                    isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
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

                // Subtasks toggle button
                if (widget.showSubTasksToggle && widget.onSubTasksToggle != null && widget.hasItems)
                  FilterIconButton(
                    icon: widget.showSubTasks ? Icons.account_tree : Icons.account_tree_outlined,
                    iconSize: AppTheme.iconSizeMedium,
                    color: widget.showSubTasks
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    tooltip: _translationService.translate(TaskTranslationKeys.showSubTasksTooltip),
                    onPressed: () {
                      final newState = !widget.showSubTasks;
                      widget.onSubTasksToggle!(newState);
                    },
                  ),

                // Sort button
                if (widget.showSortButton && widget.onSortChange != null)
                  SortDialogButton<TaskSortFields>(
                    iconColor: Theme.of(context).primaryColor,
                    tooltip: _translationService.translate(SharedTranslationKeys.sort),
                    config: widget.sortConfig ?? TaskDefaults.sorting,
                    defaultConfig: TaskDefaults.sorting,
                    onConfigChanged: widget.onSortChange!,
                    availableOptions: [
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.title,
                        direction: SortDirection.asc,
                        translationKey: TaskTranslationKeys.titleLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.priority,
                        direction: SortDirection.desc,
                        translationKey: TaskTranslationKeys.priorityLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.plannedDate,
                        direction: SortDirection.asc,
                        translationKey: TaskTranslationKeys.plannedDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.deadlineDate,
                        direction: SortDirection.asc,
                        translationKey: TaskTranslationKeys.deadlineDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.estimatedTime,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.timeDisplayEstimated,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.totalDuration,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.timeDisplayElapsed,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.createdDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.createdDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.modifiedDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.modifiedDateLabel,
                      ),
                    ],
                    showCustomOrderOption: true,
                  ),

                // Layout toggle button (only show when custom sort is enabled)
                if (widget.showLayoutToggle &&
                    widget.sortConfig?.useCustomOrder == true &&
                    widget.onLayoutToggleChange != null)
                  FilterIconButton(
                    icon: widget.forceOriginalLayout ? Icons.reorder_outlined : Icons.reorder,
                    iconSize: AppTheme.iconSizeMedium,
                    color: !widget.forceOriginalLayout ? Theme.of(context).primaryColor : Colors.grey,
                    tooltip: widget.forceOriginalLayout
                        ? _translationService.translate(SharedTranslationKeys.enableReorderingTooltip)
                        : _translationService.translate(SharedTranslationKeys.disableReorderingTooltip),
                    onPressed: () => widget.onLayoutToggleChange!(!widget.forceOriginalLayout),
                  ),

                // Group button
                if (widget.showGroupingOption && widget.onSortChange != null)
                  GroupDialogButton<TaskSortFields>(
                    iconColor: Theme.of(context).primaryColor,
                    tooltip: _translationService.translate(SharedTranslationKeys.sortEnableGrouping),
                    config: widget.sortConfig ?? TaskDefaults.sorting,
                    onConfigChanged: widget.onSortChange!,
                    availableOptions: [
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.priority,
                        translationKey: TaskTranslationKeys.priorityLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.plannedDate,
                        translationKey: TaskTranslationKeys.plannedDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.deadlineDate,
                        translationKey: TaskTranslationKeys.deadlineDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.createdDate,
                        translationKey: SharedTranslationKeys.createdDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.modifiedDate,
                        translationKey: SharedTranslationKeys.modifiedDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.title,
                        translationKey: TaskTranslationKeys.titleLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.estimatedTime,
                        translationKey: SharedTranslationKeys.timeDisplayEstimated,
                      ),
                      SortOptionWithTranslationKey(
                        field: TaskSortFields.totalDuration,
                        translationKey: SharedTranslationKeys.timeDisplayElapsed,
                      ),
                    ],
                  ),

                // Save button
                if (widget.showSaveButton)
                  SaveButton(
                    hasUnsavedChanges: hasUnsavedChanges,
                    showSavedMessage: showSavedMessage,
                    onSave: saveFilterSettings,
                    tooltip: _translationService.translate(SharedTranslationKeys.saveListOptions),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
