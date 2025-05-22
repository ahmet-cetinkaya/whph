import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/settings/constants/setting_keys.dart';
import 'package:whph/presentation/features/tasks/models/task_list_option_settings.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

import 'package:whph/presentation/shared/services/filter_settings_manager.dart';

class TaskListOptions extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Selected start date for filtering
  final DateTime? selectedStartDate;

  /// Selected end date for filtering
  final DateTime? selectedEndDate;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<TaskSortFields>? sortConfig;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when date filter changes
  final Function(DateTime?, DateTime?)? onDateFilterChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Callback when sort changes
  final Function(SortConfig<TaskSortFields>)? onSortChange;

  /// Callback when filter/sort settings are saved
  final Function()? onSaveSettings;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the date filter button
  final bool showDateFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the sort button
  final bool showSortButton;

  /// Whether to show the save button
  final bool showSaveButton;

  /// Whether to show the completed tasks toggle button
  final bool showCompletedTasksToggle;

  /// Current state of completed tasks toggle
  final bool showCompletedTasks;

  /// Callback when completed tasks toggle changes
  final Function(bool)? onCompletedTasksToggle;

  /// Whether there are items to filter
  final bool hasItems;

  /// Whether current filter settings differ from saved/default settings
  final bool hasUnsavedChanges;

  /// Key for storing settings in persistent storage
  final String? settingKeyVariantSuffix;

  /// Callback when settings are loaded
  final VoidCallback? onSettingsLoaded;

  const TaskListOptions({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.selectedStartDate,
    this.selectedEndDate,
    this.search,
    this.sortConfig,
    this.onTagFilterChange,
    this.onDateFilterChange,
    this.onSearchChange,
    this.onSortChange,
    this.onSaveSettings,
    this.showTagFilter = true,
    this.showDateFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    this.showSaveButton = true,
    this.showCompletedTasksToggle = true,
    this.showCompletedTasks = false,
    this.onCompletedTasksToggle,
    this.hasItems = true,
    this.hasUnsavedChanges = false,
    this.settingKeyVariantSuffix,
    this.onSettingsLoaded,
  });

  @override
  State<TaskListOptions> createState() => _TaskListOptionsState();
}

class _TaskListOptionsState extends State<TaskListOptions> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  late final FilterSettingsManager _filterSettingsManager;
  Timer? _searchDebounce;
  Timer? _savedMessageTimer;
  Timer? _searchStateCheckTimer;
  bool _hasUnsavedChanges = false;
  bool _showSavedMessage = false;
  String? _lastSearchQuery;

  late final String _settingKey;

  @override
  void initState() {
    super.initState();

    _filterSettingsManager = FilterSettingsManager(_mediator);

    _settingKey = widget.settingKeyVariantSuffix != null
        ? "${SettingKeys.tasksListOptionsSettings}_${widget.settingKeyVariantSuffix}"
        : SettingKeys.tasksListOptionsSettings;

    _loadSavedFilterSettings();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _savedMessageTimer?.cancel();
    _searchStateCheckTimer?.cancel();
    super.dispose();
  }

  /// Load saved filter settings from persistent storage
  Future<void> _loadSavedFilterSettings() async {
    try {
      final savedSettings = await _filterSettingsManager.loadFilterSettings(
        settingKey: _settingKey,
      );

      if (savedSettings != null && mounted) {
        final filterSettings = TaskListOptionSettings.fromJson(savedSettings);

        setState(() {
          _lastSearchQuery = filterSettings.search;
        });

        if (widget.onTagFilterChange != null) {
          final tagIds = filterSettings.selectedTagIds ?? [];
          final showNoTags = filterSettings.showNoTagsFilter;

          widget.onTagFilterChange!(
            tagIds.map((id) => DropdownOption<String>(value: id, label: id)).toList(),
            showNoTags,
          );
        }

        if (widget.onDateFilterChange != null) {
          widget.onDateFilterChange!(
            filterSettings.selectedStartDate,
            filterSettings.selectedEndDate,
          );
        }

        if (widget.onSearchChange != null && filterSettings.search != null) {
          widget.onSearchChange!(filterSettings.search);
        }

        if (widget.onCompletedTasksToggle != null) {
          widget.onCompletedTasksToggle!(filterSettings.showCompletedTasks);
        }

        if (widget.onSortChange != null && filterSettings.sortConfig != null) {
          widget.onSortChange!(filterSettings.sortConfig!);
        }
      }

      widget.onSettingsLoaded?.call();
    } catch (e) {
      widget.onSettingsLoaded?.call();
    }
  }

  /// Save current filter settings to persistent storage
  Future<void> _saveFilterSettings() async {
    final settings = TaskListOptionSettings(
      selectedTagIds: widget.selectedTagIds,
      showNoTagsFilter: widget.showNoTagsFilter,
      selectedStartDate: widget.selectedStartDate,
      selectedEndDate: widget.selectedEndDate,
      search: _lastSearchQuery, // Use _lastSearchQuery instead of widget.search
      showCompletedTasks: widget.showCompletedTasks,
      sortConfig: widget.sortConfig,
    );

    try {
      await _filterSettingsManager.saveFilterSettings(
        settingKey: _settingKey,
        filterSettings: settings.toJson(),
      );

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _showSavedMessage = true;
        });

        // Auto-hide the saved message after 2 seconds
        _savedMessageTimer?.cancel();
        _savedMessageTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSavedMessage = false;
            });
          }
        });
      }

      // Notify parent that settings were saved
      widget.onSaveSettings?.call();
    } catch (e) {
      // Handle error
    }
  }

  /// Check if current filter settings differ from saved settings
  Future<void> _checkForUnsavedChanges() async {
    final currentSettings = TaskListOptionSettings(
      selectedTagIds: widget.selectedTagIds,
      showNoTagsFilter: widget.showNoTagsFilter,
      selectedStartDate: widget.selectedStartDate,
      selectedEndDate: widget.selectedEndDate,
      search: _lastSearchQuery, // Use _lastSearchQuery instead of widget.search
      showCompletedTasks: widget.showCompletedTasks,
      sortConfig: widget.sortConfig,
    ).toJson();

    final hasChanges = await _filterSettingsManager.hasUnsavedChanges(
      settingKey: _settingKey,
      currentSettings: currentSettings,
    );

    if (mounted && _hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  void _handleFilterChange() {
    _checkForUnsavedChanges();
  }

  bool _hasFilterChanges(TaskListOptions oldWidget) {
    final hasNonSearchChanges = widget.selectedTagIds != oldWidget.selectedTagIds ||
        widget.showNoTagsFilter != oldWidget.showNoTagsFilter ||
        widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate ||
        widget.showCompletedTasks != oldWidget.showCompletedTasks ||
        widget.sortConfig != oldWidget.sortConfig;

    if (hasNonSearchChanges) {
      return true;
    }

    // Handle search changes in _hasSearchChanges instead
    return false;
  }

  bool _hasSearchChanges(TaskListOptions oldWidget) {
    final hasChanges = widget.search != oldWidget.search;
    return hasChanges;
  }

  @override
  void didUpdateWidget(TaskListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasFilterChanges = _hasFilterChanges(oldWidget);
    final hasSearchChanges = _hasSearchChanges(oldWidget);
    final isFromSearchCallback = _searchDebounce?.isActive == true || _searchStateCheckTimer?.isActive == true;

    if (hasFilterChanges || (hasSearchChanges && !isFromSearchCallback)) {
      // Force immediate check for unsaved changes
      Future.microtask(_handleFilterChange);
    }
  }

  void _onSearchChanged(String? query) {
    _searchDebounce?.cancel();
    _searchStateCheckTimer?.cancel();

    _lastSearchQuery = query;

    // Since the parent isn't updating its state immediately,
    // we need to force a check for unsaved changes here
    void processSearchChange() {
      if (!mounted) return;

      // Call parent widget's callback
      widget.onSearchChange?.call(query);

      // Force immediate check for unsaved changes
      _handleFilterChange();

      // Keep monitoring for state changes to update the UI when parent updates
      _searchStateCheckTimer?.cancel();
      _searchStateCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (widget.search == query) {
          timer.cancel();
          _handleFilterChange(); // Check again after state is updated
        } else if (timer.tick >= 50) {
          // Extended to 5 seconds for slower state updates
          timer.cancel();
          _handleFilterChange(); // Force one last check
        }
      });
    }

    // Always process search changes immediately now
    processSearchChange();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showDateFilter && widget.onDateFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null) ||
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
                          ? primaryColor
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
                  if (widget.showDateFilter && widget.onDateFilterChange != null)
                    DateRangeFilter(
                      selectedStartDate: widget.selectedStartDate,
                      selectedEndDate: widget.selectedEndDate,
                      onDateFilterChange: widget.onDateFilterChange!,
                      iconColor: (widget.selectedStartDate != null || widget.selectedEndDate != null)
                          ? primaryColor
                          : Colors.grey,
                    ),

                  // Search filter
                  if (widget.showSearchFilter && widget.onSearchChange != null)
                    // Use key based on search value to force recreation when _lastSearchQuery changes
                    SearchFilter(
                      key: ValueKey<String?>(_lastSearchQuery),
                      initialValue: _lastSearchQuery ?? widget.search,
                      onSearch: _onSearchChanged,
                      placeholder: _translationService.translate(TaskTranslationKeys.searchTasksPlaceholder),
                      iconSize: AppTheme.iconSizeMedium,
                      iconColor:
                          (_lastSearchQuery != null && _lastSearchQuery!.isNotEmpty) ? primaryColor : Colors.grey,
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

                  // Sort button
                  if (widget.showSortButton && widget.onSortChange != null)
                    SortDialogButton<TaskSortFields>(
                      iconColor: Theme.of(context).primaryColor,
                      tooltip: _translationService.translate(SharedTranslationKeys.sort),
                      config: widget.sortConfig ??
                          SortConfig<TaskSortFields>(
                            orderOptions: [
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
                            ],
                            useCustomOrder: false,
                          ),
                      defaultConfig: SortConfig<TaskSortFields>(
                        orderOptions: [
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
                        ],
                        useCustomOrder: false,
                      ),
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
                          translationKey: TaskTranslationKeys.estimatedTimeLabel,
                        ),
                        SortOptionWithTranslationKey(
                          field: TaskSortFields.totalDuration,
                          direction: SortDirection.desc,
                          translationKey: TaskTranslationKeys.elapsedTimeLabel,
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
                      isActive: widget.sortConfig?.orderOptions.isNotEmpty ?? false,
                    ),

                  // Save or Done indication
                  if (widget.showSaveButton) ...[
                    if (_showSavedMessage || _hasUnsavedChanges)
                      // Vertical divider
                      Container(
                        width: 1,
                        height: 24,
                        color: AppTheme.surface3,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                    // Save button or saved message
                    if (_showSavedMessage)
                      Row(
                        children: [
                          const Icon(
                            Icons.done,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _translationService.translate(SharedTranslationKeys.savedButton),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      )
                    else if (_hasUnsavedChanges)
                      IconButton(
                        icon: const Icon(Icons.save),
                        color: primaryColor,
                        tooltip: _translationService.translate(SharedTranslationKeys.saveButton),
                        onPressed: _saveFilterSettings,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
