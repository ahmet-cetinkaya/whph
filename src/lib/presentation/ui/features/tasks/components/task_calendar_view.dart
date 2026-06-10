import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_calendar_event.dart';
import 'package:whph/presentation/ui/features/tasks/services/task_calendar_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';

enum CalendarSubView { month, week, day, schedule }

class TaskCalendarView extends StatefulWidget {
  final TaskCalendarService calendarService;
  final void Function(String taskId) onOpenDetails;
  final void Function(DateTime plannedDate)? onCreateTask;
  final VoidCallback? onInitialLoadComplete;

  const TaskCalendarView({
    super.key,
    required this.calendarService,
    required this.onOpenDetails,
    this.onCreateTask,
    this.onInitialLoadComplete,
  });

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  final _tasksService = container.resolve<TasksService>();

  CalendarSubView _currentSubView = CalendarSubView.week;
  ViewConfiguration _viewConfiguration = MultiDayViewConfiguration.week();
  Key _calendarKey = UniqueKey();

  bool _isLoading = false;
  bool _listenerAdded = false;
  bool _isTransitioning = false;
  bool _tasksListenersAdded = false;

  @override
  void initState() {
    super.initState();
    _addTasksServiceListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialEvents();
    });
  }

  Future<void> _loadInitialEvents() async {
    if (!mounted || _isLoading) return;

    _isLoading = true;

    try {
      final range = widget.calendarService.calendarController.visibleDateTimeRange.value;

      if (range != null) {
        await widget.calendarService.loadEventsForRange(range);
      } else {
        final now = DateTime.now();
        await widget.calendarService.loadEventsForRange(DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now.add(const Duration(days: 30)),
        ));
      }

      if (mounted && !_listenerAdded) {
        widget.calendarService.calendarController.visibleDateTimeRange.addListener(_onVisibleRangeChanged);
        _listenerAdded = true;
      }

      if (mounted) {
        widget.onInitialLoadComplete?.call();
      }
    } catch (e) {
      debugPrint('TaskCalendarView: Error in _loadInitialEvents: $e');
    } finally {
      if (mounted) _isLoading = false;
    }
  }

  void _onVisibleRangeChanged() {
    if (!mounted || _isLoading) return;

    final range = widget.calendarService.calendarController.visibleDateTimeRange.value;
    if (range != null) _loadEventsForRange(range);
  }

  Future<void> _loadEventsForRange(DateTimeRange range) async {
    if (!mounted || _isLoading) return;

    _isLoading = true;

    try {
      await widget.calendarService.loadEventsForRange(range);
    } catch (e) {
      debugPrint('TaskCalendarView: Error loading events: $e');
    } finally {
      if (mounted) _isLoading = false;
    }
  }

  void _switchSubView(CalendarSubView subView) {
    if (_isTransitioning) return;
    if (_currentSubView == subView) return;

    if (_listenerAdded) {
      widget.calendarService.calendarController.visibleDateTimeRange.removeListener(_onVisibleRangeChanged);
      _listenerAdded = false;
    }

    widget.calendarService.resetEventsController();

    // Frame 1: Remove CalendarView from tree so old widget fully disposes
    setState(() {
      _calendarKey = UniqueKey();
      _currentSubView = subView;
      _isTransitioning = true;
      switch (subView) {
        case CalendarSubView.month:
          _viewConfiguration = MonthViewConfiguration.singleMonth();
        case CalendarSubView.week:
          _viewConfiguration = MultiDayViewConfiguration.week();
        case CalendarSubView.day:
          _viewConfiguration = MultiDayViewConfiguration.singleDay();
        case CalendarSubView.schedule:
          _viewConfiguration = ScheduleViewConfiguration.paginated();
      }
    });

    // Frame 2: Old widget fully disposed. Now create new CalendarView
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isTransitioning = false;
      });

      // Frame 3: New widget mounted, safe to load events and add listener
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (!_listenerAdded) {
          widget.calendarService.calendarController.visibleDateTimeRange.addListener(_onVisibleRangeChanged);
          _listenerAdded = true;
        }

        final range = widget.calendarService.calendarController.visibleDateTimeRange.value;
        if (range != null) _loadEventsForRange(range);
      });
    });
  }

  void _onTaskCreatedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskCreated(_tasksService.onTaskCreated.value ?? '');
  }

  void _onTaskUpdatedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskUpdated(_tasksService.onTaskUpdated.value ?? '');
  }

  void _onTaskDeletedListener() {
    if (!mounted) return;
    final taskId = _tasksService.onTaskDeleted.value;
    if (taskId != null) widget.calendarService.onTaskDeleted(taskId);
  }

  void _onTaskCompletedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskUpdated(_tasksService.onTaskCompleted.value ?? '');
  }

  void _addTasksServiceListeners() {
    if (_tasksListenersAdded) return;
    _tasksService.onTaskCreated.addListener(_onTaskCreatedListener);
    _tasksService.onTaskUpdated.addListener(_onTaskUpdatedListener);
    _tasksService.onTaskDeleted.addListener(_onTaskDeletedListener);
    _tasksService.onTaskCompleted.addListener(_onTaskCompletedListener);
    _tasksListenersAdded = true;
  }

  void _removeTasksServiceListeners() {
    if (!_tasksListenersAdded) return;
    _tasksService.onTaskCreated.removeListener(_onTaskCreatedListener);
    _tasksService.onTaskUpdated.removeListener(_onTaskUpdatedListener);
    _tasksService.onTaskDeleted.removeListener(_onTaskDeletedListener);
    _tasksService.onTaskCompleted.removeListener(_onTaskCompletedListener);
    _tasksListenersAdded = false;
  }

  @override
  void dispose() {
    _removeTasksServiceListeners();
    try {
      if (_listenerAdded) {
        widget.calendarService.calendarController.visibleDateTimeRange.removeListener(_onVisibleRangeChanged);
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSubViewToolbar(),
        Expanded(
          child: _isTransitioning
              ? const SizedBox.shrink()
              : CalendarView<TaskCalendarEventData>(
                  key: _calendarKey,
                  eventsController: widget.calendarService.eventsController,
                  calendarController: widget.calendarService.calendarController,
                  viewConfiguration: _viewConfiguration,
                  callbacks: CalendarCallbacks<TaskCalendarEventData>(
                    onEventTapped: _onEventTapped,
                    onEventChanged: _onEventChanged,
                    onTapped: _onEmptySlotTapped,
                  ),
                  header: CalendarHeader<TaskCalendarEventData>(
                    multiDayTileComponents: _buildTileComponents(),
                  ),
                  body: CalendarBody<TaskCalendarEventData>(
                    multiDayTileComponents: _buildTileComponents(),
                    monthTileComponents: _buildTileComponents(),
                    scheduleTileComponents: _buildScheduleTileComponents(),
                    interaction: CalendarInteraction(
                      allowResizing: true,
                      allowRescheduling: true,
                      allowEventCreation: false,
                    ),
                    snapping: const CalendarSnapping(snapIntervalMinutes: 15),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSubViewToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: CalendarSubView.values.map((subView) {
          final isSelected = _currentSubView == subView;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text(_subViewLabel(subView)),
              selected: isSelected,
              onSelected: (_) => _switchSubView(subView),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _subViewLabel(CalendarSubView subView) {
    return switch (subView) {
      CalendarSubView.month => 'Month',
      CalendarSubView.week => 'Week',
      CalendarSubView.day => 'Day',
      CalendarSubView.schedule => 'Schedule',
    };
  }

  void _onEventTapped(CalendarEvent<TaskCalendarEventData> event, RenderBox renderBox) {
    final data = event.data;
    if (data != null) {
      widget.onOpenDetails(data.taskId);
    }
  }

  Future<void> _onEventChanged(
    CalendarEvent<TaskCalendarEventData> original,
    CalendarEvent<TaskCalendarEventData> updated,
  ) async {
    await widget.calendarService.handleEventChanged(original, updated);
  }

  void _onEmptySlotTapped(DateTime date) {
    if (widget.onCreateTask != null) {
      widget.onCreateTask!(date);
    }
  }

  TileComponents<TaskCalendarEventData> _buildTileComponents() {
    return TileComponents<TaskCalendarEventData>(
      tileBuilder: _buildEventTile,
      tileWhenDraggingBuilder: (event) => _buildEventTile(
          event,
          DateTimeRange(
            start: event.start,
            end: event.end,
          )),
      feedbackTileBuilder: (event, size) => _buildEventTile(
          event,
          DateTimeRange(
            start: event.start,
            end: event.end,
          )),
      dropTargetTile: (event) => Opacity(
        opacity: 0.5,
        child: _buildEventTile(
            event,
            DateTimeRange(
              start: event.start,
              end: event.end,
            )),
      ),
      verticalResizeHandle: Container(
        width: double.infinity,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  ScheduleTileComponents<TaskCalendarEventData> _buildScheduleTileComponents() {
    return ScheduleTileComponents<TaskCalendarEventData>(
      tileBuilder: _buildEventTile,
    );
  }

  Widget _buildEventTile(CalendarEvent<TaskCalendarEventData> event, DateTimeRange tileRange) {
    final data = event.data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final color = TaskCalendarEvent.getEventColor(data);
    final isCompleted = data.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? color.withValues(alpha: 0.4) : color,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        data.title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          overflow: TextOverflow.ellipsis,
        ),
        maxLines: 1,
      ),
    );
  }
}
