import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_add_floating_button.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/src/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  bool _isTaskListVisible = false;

  // Filter state
  List<String>? _selectedTagIds;
  bool _showCompletedTasks = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  DateFilterSetting? _dateFilterSetting;
  String? _searchQuery;
  bool _showNoTagsFilter = false;
  SortConfig<TaskSortFields> _sortConfig = TaskDefaults.sorting;

  String? _handledTaskId;
  Timer? _autoRefreshUITimer;
  bool _isLoadingSettings = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isLoadingSettings = true; // Start with loading flag true
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

  String _getAutoRefreshKey() {
    if (_dateFilterSetting?.isQuickSelection == true && _dateFilterSetting?.isAutoRefreshEnabled == true) {
      final now = DateTime.now();
      // Create a key that changes every minute for auto-refresh
      return '${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}';
    }
    return 'static';
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

  void _onSortConfigChange(SortConfig<TaskSortFields> newConfig) {
    if (!mounted) return;
    setState(() {
      _sortConfig = newConfig;
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
            HelpMenu(
              titleKey: TaskTranslationKeys.tasksHelpTitle,
              markdownContentKey: TaskTranslationKeys.tasksHelpContent,
            ),
          ],
        ),
      ],
      // Add floating action button for mobile devices
      floatingActionButton: TaskAddFloatingButton(
        initialTagIds: _showNoTagsFilter ? [] : _selectedTagIds,
        initialTitle: _searchQuery,
        initialPlannedDate: _filterStartDate,
        initialDeadlineDate: _filterEndDate,
        initialCompleted: _showCompletedTasks,
      ),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters with Completed Tasks Toggle
          TaskListOptions(
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
            showTagFilter: true,
            showDateFilter: true,
            showSearchFilter: true,
            showCompletedTasksToggle: true,
            hasItems: true,
            sortConfig: _sortConfig,
            onSortChange: _onSortConfigChange,
            settingKeyVariantSuffix: tasksListOptionsSettingsKeySuffix,
            onSettingsLoaded: _onSettingsLoaded,
          ),

          // Task List
          if (_isTaskListVisible)
            Expanded(
              child: TaskList(
                key: ValueKey('${_getAutoRefreshKey()}_${_effectiveFilterStartDate?.millisecondsSinceEpoch}_${_effectiveFilterEndDate?.millisecondsSinceEpoch}'),
                filterByCompleted: _showCompletedTasks,
                filterByTags: _showNoTagsFilter ? [] : _selectedTagIds,
                filterNoTags: _showNoTagsFilter,
                filterByPlannedStartDate: _effectiveFilterStartDate,
                filterByPlannedEndDate: _effectiveFilterEndDate,
                filterByDeadlineStartDate: _effectiveFilterStartDate,
                filterByDeadlineEndDate: _effectiveFilterEndDate,
                filterDateOr: true,
                search: _searchQuery,
                onClickTask: (task) => _openDetails(task.id),
                enableReordering: !_showCompletedTasks && _sortConfig.useCustomOrder,
                sortConfig: _sortConfig,
              ),
            ),
        ],
      ),
    );
  }
}
