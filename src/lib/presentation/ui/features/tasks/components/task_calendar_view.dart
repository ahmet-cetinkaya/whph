import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/unplanned_tasks_panel.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_calendar_event.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/features/tasks/services/task_calendar_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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
  final _translationService = container.resolve<ITranslationService>();

  CalendarSubView _currentSubView = CalendarSubView.week;
  ViewConfiguration _viewConfiguration = MultiDayViewConfiguration.week();
  Key _calendarKey = UniqueKey();

  bool _isLoading = false;
  bool _listenerAdded = false;
  bool _isTransitioning = false;
  bool _tasksListenersAdded = false;

  static const double _panelWidth = 240.0;
  static const double _toggleWidth = 32.0;

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
      Logger.error('Error in _loadInitialEvents', error: e);
    } finally {
      if (mounted) _isLoading = false;
    }
  }

  DateTimeRange? _lastLoadedRange;

  void _onVisibleRangeChanged() {
    if (!mounted) return;

    final range = widget.calendarService.calendarController.visibleDateTimeRange.value;
    if (range == null) return;

    if (_isLoading) {
      _lastLoadedRange = range;
      return;
    }
    _loadEventsForRange(range);
  }

  @override
  void didUpdateWidget(TaskCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarService != widget.calendarService) {
      _removeTasksServiceListeners();
      _lastLoadedRange = null;
      _addTasksServiceListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInitialEvents();
      });
    }
  }

  Future<void> _loadEventsForRange(DateTimeRange range) async {
    if (!mounted || _isLoading) return;

    _isLoading = true;

    try {
      await widget.calendarService.loadEventsForRange(range);
    } catch (e) {
      Logger.error('Error loading events', error: e);
    } finally {
      if (mounted) {
        _isLoading = false;
        final pendingRange = _lastLoadedRange;
        _lastLoadedRange = null;
        if (pendingRange != null && pendingRange != range) {
          _loadEventsForRange(pendingRange);
        }
      }
    }
  }

  void _switchSubView(CalendarSubView subView) {
    if (_isTransitioning) return;
    if (_currentSubView == subView) return;

    if (_listenerAdded) {
      widget.calendarService.calendarController.visibleDateTimeRange.removeListener(_onVisibleRangeChanged);
      _listenerAdded = false;
    }

    widget.calendarService.clearEvents();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isTransitioning = false;
      });

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
    widget.calendarService.onTaskCreated();
    if (widget.calendarService.isPanelOpen) widget.calendarService.loadUnplannedTasks();
  }

  void _onTaskUpdatedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskUpdated();
    if (widget.calendarService.isPanelOpen) widget.calendarService.loadUnplannedTasks();
  }

  void _onTaskDeletedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskDeleted();
    if (widget.calendarService.isPanelOpen) widget.calendarService.loadUnplannedTasks();
  }

  void _onTaskCompletedListener() {
    if (!mounted) return;
    widget.calendarService.onTaskUpdated();
    if (widget.calendarService.isPanelOpen) widget.calendarService.loadUnplannedTasks();
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

  Future<void> _togglePanel() async {
    final wasOpen = widget.calendarService.isPanelOpen;
    Logger.info('_togglePanel: wasOpen=$wasOpen', component: 'TaskCalendarView');
    widget.calendarService.isPanelOpen = !widget.calendarService.isPanelOpen;
    Logger.info('_togglePanel: isPanelOpen=${widget.calendarService.isPanelOpen}', component: 'TaskCalendarView');
    if (widget.calendarService.isPanelOpen) {
      Logger.info('_togglePanel: calling loadUnplannedTasks', component: 'TaskCalendarView');
      await widget.calendarService.loadUnplannedTasks();
      Logger.info('_togglePanel: loadUnplannedTasks completed, taskCount=${widget.calendarService.unplannedTasks.length}', component: 'TaskCalendarView');
    }
  }

  @override
  void dispose() {
    _removeTasksServiceListeners();
    try {
      if (_listenerAdded) {
        widget.calendarService.calendarController.visibleDateTimeRange.removeListener(_onVisibleRangeChanged);
      }
    } catch (e) {
      Logger.error('Error removing calendar listener', error: e);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSubViewToolbar(),
        ListenableBuilder(
          listenable: widget.calendarService,
          builder: (context, _) => _buildArmedHint(),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.calendarService,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: _isTransitioning
                      ? const SizedBox.shrink()
                      : ListenableBuilder(
                          listenable: widget.calendarService,
                          builder: (context, _) => _buildCalendarView(),
                        ),
                ),
                _buildPanelToggleButton(),
                if (widget.calendarService.isPanelOpen) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: _panelWidth,
                    child: ListenableBuilder(
                      listenable: widget.calendarService,
                      builder: (context, _) => UnplannedTasksPanel(
                        tasks: widget.calendarService.unplannedTasks,
                        onArm: widget.calendarService.armTask,
                        onOpenDetails: (task) => widget.onOpenDetails(task.id),
                        armedTaskId: widget.calendarService.armedTask?.id,
                        groupLabelResolver: (task) =>
                            widget.calendarService.resolveGroupLabel(task, _translationService.translate),
                        onClose: () {
                          widget.calendarService.isPanelOpen = false;
                        },
                        onLoadMore: widget.calendarService.loadMoreUnplannedTasks,
                        hasMore: widget.calendarService.hasMoreUnplanned,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelToggleButton() {
    final unplannedCount = widget.calendarService.unplannedTasks.length;

    return SizedBox(
      width: _toggleWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: _togglePanel,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.calendarService.isPanelOpen ? Icons.chevron_right : Icons.chevron_left,
                size: AppTheme.iconSizeSmall,
              ),
              if (!widget.calendarService.isPanelOpen && unplannedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
                    ),
                    child: Text(
                      '$unplannedCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    final isArmed = widget.calendarService.armedTask != null;

    return CalendarView<TaskCalendarEventData>(
      key: _calendarKey,
      locale: Localizations.localeOf(context).toString(),
      eventsController: widget.calendarService.eventsController,
      calendarController: widget.calendarService.calendarController,
      viewConfiguration: _viewConfiguration,
      components: CalendarComponents<TaskCalendarEventData>(
        scheduleComponents: ScheduleComponents<TaskCalendarEventData>(
          leadingDateBuilder: _buildScheduleLeadingDate,
        ),
      ),
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
        monthBodyConfiguration: MonthBodyConfiguration<TaskCalendarEventData>(),
        multiDayBodyConfiguration: const MultiDayBodyConfiguration(),
        scheduleTileComponents: _buildScheduleTileComponents(),
        scheduleBodyConfiguration: ScheduleBodyConfiguration(
          emptyDay: isArmed ? EmptyDayBehavior.show : EmptyDayBehavior.hide,
        ),
        interaction: CalendarInteraction(
          allowResizing: true,
          allowRescheduling: true,
          allowEventCreation: false,
        ),
        snapping: const CalendarSnapping(snapIntervalMinutes: 15),
      ),
    );
  }

  Widget _buildArmedHint() {
    final armed = widget.calendarService.armedTask;
    if (armed == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeXSmall),
      child: Row(
        children: [
          Icon(Icons.touch_app, size: AppTheme.iconSizeSmall, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: AppTheme.sizeXSmall),
          Expanded(
            child: Text(
              _translationService.translate(
                TaskTranslationKeys.unplannedTasksPanelArmHint,
                namedArgs: {'title': armed.title},
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: widget.calendarService.disarmTask,
            child: Text(_translationService.translate(TaskTranslationKeys.unplannedTasksPanelArmCancel)),
          ),
        ],
      ),
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
    final key = switch (subView) {
      CalendarSubView.month => TaskTranslationKeys.calendarSubViewMonth,
      CalendarSubView.week => TaskTranslationKeys.calendarSubViewWeek,
      CalendarSubView.day => TaskTranslationKeys.calendarSubViewDay,
      CalendarSubView.schedule => TaskTranslationKeys.calendarSubViewSchedule,
    };
    return _translationService.translate(key);
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
    if (_assignArmedToDate(date)) return;
    widget.onCreateTask?.call(date);
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
      emptyItemBuilder: (tileRange) => _buildScheduleEmptyDay(tileRange.start),
    );
  }

  /// Assigns the armed task to [date] when scheduling via the schedule view.
  /// Returns true if a task was armed and assigned.
  bool _assignArmedToDate(DateTime date) {
    final armed = widget.calendarService.armedTask;
    if (armed == null) return false;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    widget.calendarService.assignTaskToDate(armed.id, normalizedDate);
    return true;
  }

  Widget _buildScheduleEmptyDay(DateTime date) {
    final isArmed = widget.calendarService.armedTask != null;
    final label = Text(
      _translationService.translate(TaskTranslationKeys.unplannedTasksPanelEmpty),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
    );

    if (!isArmed) return label;

    return InkWell(
      onTap: () => _assignArmedToDate(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
        child: Row(
          children: [
            Icon(Icons.add, size: AppTheme.iconSizeSmall, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppTheme.sizeXSmall),
            Expanded(child: label),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleLeadingDate(InternalDateTime date, ScheduleDateStyle? style) {
    final defaultWidget = ScheduleDate.builder(date, style);
    if (widget.calendarService.armedTask == null) return defaultWidget;

    return InkWell(
      onTap: () => _assignArmedToDate(date),
      child: defaultWidget,
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
