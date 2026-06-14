import 'package:acore/queries/models/sort_option.dart';
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_calendar_event.dart';

class TaskCalendarService extends ChangeNotifier {
  static const int _minutesPerDay = 1440;
  final Mediator _mediator;
  final DefaultEventsController<TaskCalendarEventData> _eventsController =
      DefaultEventsController<TaskCalendarEventData>();
  final calendarController = CalendarController<TaskCalendarEventData>();
  bool _isDisposed = false;

  void clearEvents() {
    if (_isDisposed) return;
    _eventsController.clearEvents();
    notifyListeners();
  }

  DefaultEventsController<TaskCalendarEventData> get eventsController => _eventsController;

  List<String>? _filterTags;
  bool _filterNoTags = false;
  bool _showCompleted = false;
  String? _searchQuery;
  List<SortOption<TaskSortFields>>? _sortBy;
  SortOption<TaskSortFields>? _groupBy;
  bool _enableGrouping = false;

  List<TaskListItem> _unplannedTasks = [];
  List<TaskListItem> get unplannedTasks => _unplannedTasks;

  int _unplannedPageIndex = 0;
  static const int _unplannedPageSize = 50;
  bool _hasMoreUnplanned = false;
  bool get hasMoreUnplanned => _hasMoreUnplanned;

  Map<String, TaskStatusListItem> _statusById = {};
  Map<String, TaskStatusListItem> get statusById => Map.unmodifiable(_statusById);

  bool _isPanelOpen = false;
  bool get isPanelOpen => _isPanelOpen;
  set isPanelOpen(bool value) {
    if (_isPanelOpen == value) return;
    _isPanelOpen = value;
    if (_isDisposed) return;
    notifyListeners();
  }

  TaskListItem? _armedTask;
  TaskListItem? get armedTask => _armedTask;

  void armTask(TaskListItem task) {
    _armedTask = (_armedTask?.id == task.id) ? null : task;
    if (_isDisposed) return;
    notifyListeners();
  }

  void disarmTask() {
    if (_armedTask == null) return;
    _armedTask = null;
    if (_isDisposed) return;
    notifyListeners();
  }

  TaskCalendarService(this._mediator);

  void setFilters({
    List<String>? tags,
    bool noTags = false,
    bool showCompleted = false,
    String? search,
    List<SortOption<TaskSortFields>>? sortBy,
    SortOption<TaskSortFields>? groupBy,
    bool enableGrouping = false,
  }) {
    _filterTags = tags;
    _filterNoTags = noTags;
    _showCompleted = showCompleted;
    _searchQuery = search;
    _sortBy = sortBy;
    _groupBy = groupBy;
    _enableGrouping = enableGrouping;
  }

  Future<void> reloadWithFilters() async {
    if (_isDisposed) return;
    await _reloadCurrentRange();
    if (_isDisposed) return;
    if (_isPanelOpen) await loadUnplannedTasks();
  }

  static const int _eventsPageSize = 100;

  Future<void> loadEventsForRange(DateTimeRange range) async {
    try {
      final allEvents = <CalendarEvent<TaskCalendarEventData>>[];
      var pageIndex = 0;

      while (true) {
        if (_isDisposed) return;

        final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
          GetListTasksQuery(
            pageIndex: pageIndex,
            pageSize: _eventsPageSize,
            filterByPlannedStartDate: range.start,
            filterByPlannedEndDate: range.end,
            filterDateOr: true,
            includeNullDates: false,
            filterByCompleted: _showCompleted ? null : false,
            filterByTags: _filterNoTags ? [] : _filterTags,
            filterNoTags: _filterNoTags,
            filterBySearch: _searchQuery,
            enableGrouping: false,
          ),
        );

        if (_isDisposed) return;

        allEvents.addAll(
          response.items
              .where((task) => task.plannedDate != null)
              .map((task) => TaskCalendarEvent.fromTaskListItem(task)),
        );

        if (!response.hasNext) break;
        pageIndex++;
      }

      if (_isDisposed) return;
      _eventsController.clearEvents();
      _eventsController.addEvents(allEvents);
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Failed to load events', error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
    }
  }

  Future<void> handleEventChanged(
    CalendarEvent<TaskCalendarEventData> original,
    CalendarEvent<TaskCalendarEventData> updated,
  ) async {
    final data = updated.data;
    if (data == null) return;

    final durationDiff = updated.duration.inMinutes - original.duration.inMinutes;
    final hasTimeChange = durationDiff != 0;

    try {
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: data.taskId),
      );

      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
        SaveTaskCommand(
          id: task.id,
          title: task.title,
          plannedDate: updated.dateTimeRange.start,
          priority: task.priority,
          description: task.description,
          deadlineDate: task.deadlineDate,
          estimatedTime: hasTimeChange ? updated.duration.inMinutes.clamp(1, _minutesPerDay) : task.estimatedTime,
          order: task.order,
          statusId: task.statusId,
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to save event change', error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
      _reloadCurrentRange();
    }
  }

  void onTaskCreated() {
    _reloadCurrentRange();
  }

  void onTaskUpdated() {
    _reloadCurrentRange();
  }

  void onTaskDeleted() {
    _reloadCurrentRange();
  }

  Future<void> loadUnplannedTasks() async {
    try {
      Logger.info('loadUnplannedTasks: starting', component: 'TaskCalendarService');
      if (_enableGrouping && _statusById.isEmpty) {
        await _loadStatuses();
      }

      if (_isDisposed) return;

      _unplannedPageIndex = 0;
      final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(
          pageIndex: _unplannedPageIndex,
          pageSize: _unplannedPageSize,
          includeNullDates: true,
          filterByCompleted: false,
          filterByTags: _filterNoTags ? [] : _filterTags,
          filterNoTags: _filterNoTags,
          filterBySearch: _searchQuery,
          sortBy: _sortBy,
          groupBy: _enableGrouping ? _groupBy : null,
          enableGrouping: _enableGrouping,
        ),
      );

      if (_isDisposed) return;

      _unplannedTasks = response.items.where((task) => task.plannedDate == null && !task.isCompleted).toList();
      _hasMoreUnplanned = response.hasNext;
      Logger.info('loadUnplannedTasks: loaded ${_unplannedTasks.length} tasks, hasMore=$_hasMoreUnplanned',
          component: 'TaskCalendarService');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Failed to load unplanned tasks',
          error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
    }
  }

  Future<void> loadMoreUnplannedTasks() async {
    if (!_hasMoreUnplanned) return;

    try {
      if (_isDisposed) return;

      _unplannedPageIndex++;
      final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(
          pageIndex: _unplannedPageIndex,
          pageSize: _unplannedPageSize,
          includeNullDates: true,
          filterByCompleted: false,
          filterByTags: _filterNoTags ? [] : _filterTags,
          filterNoTags: _filterNoTags,
          filterBySearch: _searchQuery,
          sortBy: _sortBy,
          groupBy: _enableGrouping ? _groupBy : null,
          enableGrouping: _enableGrouping,
        ),
      );

      if (_isDisposed) return;

      _unplannedTasks.addAll(
        response.items.where((task) => task.plannedDate == null && !task.isCompleted),
      );
      _hasMoreUnplanned = response.hasNext;
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Failed to load more unplanned tasks',
          error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
    }
  }

  /// Resolves the display label for a task's group, handling status grouping
  /// (where [TaskListItem.groupName] is a statusId) and translatable keys.
  String resolveGroupLabel(TaskListItem task, String Function(String key) translate) {
    final groupName = task.groupName ?? '';

    final status = _statusById[groupName];
    if (status != null) {
      if (status.name.isEmpty) {
        return translate(
            status.isDoneStatus ? TaskTranslationKeys.statusBuiltInDone : TaskTranslationKeys.statusBuiltInTodo);
      }
      return status.name;
    }

    return task.isGroupNameTranslatable ? translate(groupName) : groupName;
  }

  Future<void> _loadStatuses() async {
    try {
      final response = await _mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
        const GetListTaskStatusesQuery(pageSize: 100),
      );
      _statusById = {for (final status in response.items) status.id: status};
    } catch (e, stackTrace) {
      Logger.error('Failed to load statuses', error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
    }
  }

  Future<void> assignTaskToDate(String taskId, DateTime date) async {
    try {
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
      );

      if (_isDisposed) return;

      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
        SaveTaskCommand(
          id: task.id,
          title: task.title,
          plannedDate: date,
          priority: task.priority,
          description: task.description,
          deadlineDate: task.deadlineDate,
          estimatedTime: task.estimatedTime,
          order: task.order,
          statusId: task.statusId,
        ),
      );

      if (_isDisposed) return;

      _unplannedTasks.removeWhere((t) => t.id == taskId);
      if (_armedTask?.id == taskId) _armedTask = null;
      notifyListeners();
      await _reloadCurrentRange();
    } catch (e, stackTrace) {
      Logger.error('Failed to assign task to date', error: e, stackTrace: stackTrace, component: 'TaskCalendarService');
    }
  }

  Future<void> _reloadCurrentRange() async {
    if (_isDisposed) return;
    final range = calendarController.visibleDateTimeRange.value;
    if (range != null) {
      await loadEventsForRange(range);
    }
  }

  void reset() {
    _eventsController.clearEvents();
    _unplannedTasks = [];
    _unplannedPageIndex = 0;
    _hasMoreUnplanned = false;
    _armedTask = null;
    _isPanelOpen = false;
    _statusById = {};
  }

  @override
  void dispose() {
    _isDisposed = true;
    _eventsController.dispose();
    calendarController.dispose();
    super.dispose();
  }
}
