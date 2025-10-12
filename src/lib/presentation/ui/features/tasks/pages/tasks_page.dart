import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_floating_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Tour keys
  final GlobalKey _addTaskButtonKey = GlobalKey();
  final GlobalKey _taskFiltersKey = GlobalKey();
  final GlobalKey _taskListKey = GlobalKey();
  final GlobalKey _floatingAddButtonKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();

  bool _isTaskListVisible = false;
  bool _isDataLoaded = false;

  // Filter state
  List<String>? _selectedTagIds;
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  DateFilterSetting? _dateFilterSetting;
  String? _searchQuery;
  bool _showNoTagsFilter = false;
  SortConfig<TaskSortFields> _sortConfig = TaskDefaults.sorting;
  bool _forceOriginalLayout = false;

  String? _handledTaskId;
  Timer? _autoRefreshUITimer;
  bool _isLoadingSettings = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isLoadingSettings = true; // Start with loading flag true
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() async {
    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;

    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        while (!_isPageFullyLoaded && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
    }
  }

  // Cache for auto-refresh dates to prevent constant recalculation
  DateTime? _cachedAutoRefreshStartDate;
  DateTime? _cachedAutoRefreshEndDate;
  DateTime? _lastAutoRefreshCheck;

  /// Get effective filter start date (calculated from DateFilterSetting if available)
  DateTime? get _effectiveFilterStartDate {
    if (_dateFilterSetting?.isQuickSelection == true && _dateFilterSetting?.isAutoRefreshEnabled == true) {
      _updateAutoRefreshCacheIfNeeded();
      return _cachedAutoRefreshStartDate ?? _filterStartDate;
    }
    return _filterStartDate;
  }

  /// Get effective filter end date (calculated from DateFilterSetting if available)
  DateTime? get _effectiveFilterEndDate {
    if (_dateFilterSetting?.isQuickSelection == true && _dateFilterSetting?.isAutoRefreshEnabled == true) {
      _updateAutoRefreshCacheIfNeeded();
      return _cachedAutoRefreshEndDate ?? _filterEndDate;
    }
    return _filterEndDate;
  }

  void _updateAutoRefreshCacheIfNeeded() {
    final now = DateTime.now();
    // Update cache only if minute has changed (for "this_minute") or if this is first check
    if (_lastAutoRefreshCheck == null ||
        now.minute != _lastAutoRefreshCheck!.minute ||
        now.hour != _lastAutoRefreshCheck!.hour ||
        now.day != _lastAutoRefreshCheck!.day) {
      final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
      _cachedAutoRefreshStartDate = currentRange.startDate;
      _cachedAutoRefreshEndDate = currentRange.endDate;
      _lastAutoRefreshCheck = now;

      // Don't call setState - let TaskList handle its own refresh
    }
  }

  Future<void> _openDetails(String taskId) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
      ),
      size: DialogSize.large,
    );
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
        _showNoTagsFilter = isNoneSelected;
      });
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
      });
    }
  }

  void _onDateFilterSettingChange(DateFilterSetting? setting) {
    if (mounted) {
      setState(() {
        _dateFilterSetting = setting;
        // Also update the legacy fields for backward compatibility
        if (setting != null) {
          final currentRange = setting.calculateCurrentDateRange();
          _filterStartDate = currentRange.startDate;
          _filterEndDate = currentRange.endDate;
        } else {
          _filterStartDate = null;
          _filterEndDate = null;
        }
      });
    }

    // Skip auto-refresh setup during settings loading to prevent unsaved changes
    if (!_isLoadingSettings) {
      _setupAutoRefreshUI();
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
    }
  }

  void _onCompletedTasksToggle(bool showCompleted) {
    if (mounted) {
      setState(() {
        _showCompletedTasks = showCompleted;
      });
    }
  }

  void _onSubTasksToggle(bool showSubTasks) {
    if (mounted) {
      setState(() {
        _showSubTasks = showSubTasks;
      });
    }
  }

  void _onSortConfigChange(SortConfig<TaskSortFields> newConfig) {
    if (!mounted) return;
    setState(() {
      _sortConfig = newConfig;
    });
  }

  void _onLayoutToggleChange(bool forceOriginalLayout) {
    if (!mounted) return;
    setState(() {
      _forceOriginalLayout = forceOriginalLayout;
    });
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isTaskListVisible = true;
      _isLoadingSettings = false;
    });
    _setupAutoRefreshUI();
  }

  void _onDataListed(int count) {
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  bool get _isPageFullyLoaded {
    return _isTaskListVisible && _isDataLoaded;
  }

  void _setupAutoRefreshUI() {
    _autoRefreshUITimer?.cancel();

    // Setup minimal timer only for auto-refresh enabled quick selections
    if (_dateFilterSetting?.isQuickSelection == true && _dateFilterSetting?.isAutoRefreshEnabled == true) {
      _autoRefreshUITimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // CRITICAL: Don't change any widget properties, just call build
        // This should not trigger didUpdateWidget since no properties change
        if (mounted) {
          // Force a rebuild without changing state
          setState(() {}); // Empty setState - no actual state change
        }
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshUITimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments to show task details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && (args.containsKey('taskId'))) {
      final taskId = args['taskId'] as String;

      // Only handle the task if we haven't already handled it or if it's a new navigation
      if (_handledTaskId != taskId) {
        _handledTaskId = taskId;

        // Schedule the dialog to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openDetails(taskId);
          }
        });
      }
    } else {
      // Check if we have a route name that includes a task ID
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null && routeName.startsWith('/tasks/') && routeName != '/tasks/details') {
        final taskId = routeName.substring('/tasks/'.length);

        // Only handle the task if we haven't already handled it
        if (_handledTaskId != taskId) {
          _handledTaskId = taskId;

          // Schedule the dialog to open after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetails(taskId);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const String tasksListOptionsSettingsKeySuffix = "TASKS_PAGE";

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TaskTranslationKeys.tasksPageTitle),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskAddButton(
              key: _addTaskButtonKey,
              onTaskCreated: (taskId, taskData) {
                // The task will be added through the event system
              },
              buttonColor: _themeService.primaryColor,
              initialTagIds: _showNoTagsFilter ? [] : _selectedTagIds,
              initialTitle: _searchQuery,
              initialPlannedDate: _filterStartDate,
              initialDeadlineDate: _filterEndDate,
              initialCompleted: _showCompletedTasks,
            ),
            KebabMenu(
              helpTitleKey: TaskTranslationKeys.tasksHelpTitle,
              helpMarkdownContentKey: TaskTranslationKeys.tasksHelpContent,
              onStartTour: _startIndividualTour,
            ),
          ],
        ),
      ],
      // Add floating action button for mobile devices
      floatingActionButton: TaskAddFloatingButton(
        key: _floatingAddButtonKey,
        initialTagIds: _showNoTagsFilter ? [] : _selectedTagIds,
        initialTitle: _searchQuery,
        initialPlannedDate: _filterStartDate,
        initialDeadlineDate: _filterEndDate,
        initialCompleted: _showCompletedTasks,
      ),
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Column(
          key: _mainContentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters with Completed Tasks Toggle
            TaskListOptions(
              key: _taskFiltersKey,
              selectedTagIds: _selectedTagIds,
              showNoTagsFilter: _showNoTagsFilter,
              selectedStartDate: _filterStartDate,
              selectedEndDate: _filterEndDate,
              dateFilterSetting: _dateFilterSetting,
              onTagFilterChange: _onFilterTags,
              onDateFilterChange: _onDateFilterChange,
              onDateFilterSettingChange: _onDateFilterSettingChange,
              onSearchChange: _onSearchChange,
              showCompletedTasks: _showCompletedTasks,
              onCompletedTasksToggle: _onCompletedTasksToggle,
              showSubTasks: _showSubTasks,
              onSubTasksToggle: _onSubTasksToggle,
              showTagFilter: true,
              showDateFilter: true,
              showSearchFilter: true,
              showCompletedTasksToggle: true,
              showSubTasksToggle: true,
              hasItems: true,
              sortConfig: _sortConfig,
              forceOriginalLayout: _forceOriginalLayout,
              onSortChange: _onSortConfigChange,
              onLayoutToggleChange: _onLayoutToggleChange,
              settingKeyVariantSuffix: tasksListOptionsSettingsKeySuffix,
              onSettingsLoaded: _onSettingsLoaded,
            ),

            // Task List
            if (_isTaskListVisible)
              Expanded(
                child: TaskList(
                  key: _taskListKey,
                  filterByCompleted: _showCompletedTasks,
                  filterByTags: _showNoTagsFilter ? [] : _selectedTagIds,
                  filterNoTags: _showNoTagsFilter,
                  filterByPlannedStartDate: _effectiveFilterStartDate,
                  filterByPlannedEndDate: _effectiveFilterEndDate,
                  filterByDeadlineStartDate: _effectiveFilterStartDate,
                  filterByDeadlineEndDate: _effectiveFilterEndDate,
                  filterDateOr: true,
                  search: _searchQuery,
                  includeSubTasks: _showSubTasks,
                  onClickTask: (task) => _openDetails(task.id),
                  onList: _onDataListed,
                  enableReordering: !_showCompletedTasks && _sortConfig.useCustomOrder,
                  forceOriginalLayout: _forceOriginalLayout,
                  sortConfig: _sortConfig,
                  useParentScroll: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourTaskManagementTitle),
        description: _translationService.translate(TaskTranslationKeys.tourTaskManagementDescription),
        icon: Icons.check_circle_outline,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. Add task button introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourAddTasksTitle),
        description: _translationService.translate(TaskTranslationKeys.tourAddTasksDescription),
        targetKey: _addTaskButtonKey,
        position: TourPosition.bottom,
      ),
      // 3. Tasks list introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourYourTasksTitle),
        description: _translationService.translate(TaskTranslationKeys.tourYourTasksDescription),
        targetKey: _taskListKey,
        position: TourPosition.top,
      ),
      // 4. List options introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourFilterSearchTitle),
        description: _translationService.translate(TaskTranslationKeys.tourFilterSearchDescription),
        targetKey: _taskFiltersKey,
        position: TourPosition.bottom,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(context);
          }
        },
        onSkip: () async {
          if (isMultiPageTour) {
            await TourNavigationService.skipMultiPageTour();
          }
          if (context.mounted) Navigator.of(context).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(context)
            : null,
        showBackButton: isMultiPageTour,
        isFinalPageOfTour: !isMultiPageTour || TourNavigationService.currentTourIndex == 5, // Notes page is final
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }
}
