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
  final Mediator _mediator;
  DefaultEventsController<TaskCalendarEventData> eventsController = DefaultEventsController<TaskCalendarEventData>();
  final calendarController = CalendarController<TaskCalendarEventData>();

  void resetEventsController() {
    eventsController = DefaultEventsController<TaskCalendarEventData>();
  }

  List<String>? _filterTags;
  bool _filterNoTags = false;
  bool _showCompleted = false;
  String? _searchQuery;
  List<SortOption<TaskSortFields>>? _sortBy;
  SortOption<TaskSortFields>? _groupBy;
  bool _enableGrouping = false;

  List<TaskListItem> _unplannedTasks = [];
  List<TaskListItem> get unplannedTasks => _unplannedTasks;

  Map<String, TaskStatusListItem> _statusById = {};
  Map<String, TaskStatusListItem> get statusById => _statusById;

  bool _isPanelOpen = false;
  set isPanelOpen(bool value) => _isPanelOpen = value;

  TaskListItem? _armedTask;
  TaskListItem? get armedTask => _armedTask;

  void armTask(TaskListItem task) {
    _armedTask = (_armedTask?.id == task.id) ? null : task;
    notifyListeners();
  }

  void disarmTask() {
    if (_armedTask == null) return;
    _armedTask = null;
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
    await _reloadCurrentRange();
    if (_isPanelOpen) await loadUnplannedTasks();
  }

  Future<void> loadEventsForRange(DateTimeRange range) async {
    try {
      final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(
          pageIndex: 0,
          // TODO(#286): page through results instead of capping at 500
          pageSize: 500,
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

      final events = response.items
          .where((task) => task.plannedDate != null)
          .map((task) => TaskCalendarEvent.fromTaskListItem(task))
          .toList();

      eventsController.clearEvents();
      eventsController.addEvents(events);
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to load events', error: e);
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
          estimatedTime: hasTimeChange ? updated.duration.inMinutes : task.estimatedTime,
          order: task.order,
          statusId: task.statusId,
        ),
      );
    } catch (e) {
      Logger.error('Failed to save event change', error: e);
      _reloadCurrentRange();
    }
  }

  void onTaskCreated(String taskId) {
    _reloadCurrentRange();
  }

  void onTaskUpdated(String taskId) {
    _reloadCurrentRange();
  }

  void onTaskDeleted(String taskId) {
    _reloadCurrentRange();
  }

  Future<void> loadUnplannedTasks() async {
    try {
      if (_enableGrouping && _statusById.isEmpty) {
        await _loadStatuses();
      }

      final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(
          pageIndex: 0,
          // TODO(#286): page through results instead of capping at 500
          pageSize: 500,
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
      _unplannedTasks = response.items.where((task) => task.plannedDate == null && !task.isCompleted).toList();
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to load unplanned tasks', error: e);
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
    } catch (e) {
      Logger.error('Failed to load statuses', error: e);
    }
  }

  Future<void> assignTaskToDate(String taskId, DateTime date) async {
    try {
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
      );

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
      _unplannedTasks.removeWhere((t) => t.id == taskId);
      if (_armedTask?.id == taskId) _armedTask = null;
      notifyListeners();
      await _reloadCurrentRange();
    } catch (e) {
      Logger.error('Failed to assign task to date', error: e);
    }
  }

  Future<void> _reloadCurrentRange() async {
    final range = calendarController.visibleDateTimeRange.value;
    if (range != null) {
      await loadEventsForRange(range);
    }
  }

  @override
  void dispose() {
    eventsController.dispose();
    calendarController.dispose();
    super.dispose();
  }
}
