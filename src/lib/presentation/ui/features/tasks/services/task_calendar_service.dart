import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
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

  TaskCalendarService(this._mediator);

  void setFilters({
    List<String>? tags,
    bool noTags = false,
    bool showCompleted = false,
    String? search,
  }) {
    _filterTags = tags;
    _filterNoTags = noTags;
    _showCompleted = showCompleted;
    _searchQuery = search;
  }

  Future<void> loadEventsForRange(DateTimeRange range) async {
    try {
      final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(
          pageIndex: 0,
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
      debugPrint('TaskCalendarService: Failed to load events: $e');
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
      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
        SaveTaskCommand(
          id: data.taskId,
          title: data.title,
          plannedDate: updated.dateTimeRange.start,
          estimatedTime: hasTimeChange ? updated.duration.inMinutes : null,
        ),
      );
    } catch (e) {
      debugPrint('TaskCalendarService: Failed to save event change: $e');
      eventsController.removeEvent(updated);
      eventsController.addEvent(original);
      notifyListeners();
    }
  }

  void onTaskCreated(String taskId) {
    _reloadCurrentRange();
  }

  void onTaskUpdated(String taskId) {
    _reloadCurrentRange();
  }

  void onTaskDeleted(String taskId) {
    eventsController.removeWhere((key, event) => event.data?.taskId == taskId);
    notifyListeners();
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
