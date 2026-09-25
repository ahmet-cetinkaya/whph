import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tags/queries/get_elements_by_time_query.dart';
import 'package:whph/core/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

const _queryPageSize = 200;
const _maximumAggregateItems = 10000;
const _maximumCalendarDays = 93;
const _maximumAnalysisDays = 366;
const _defaultAnalysisLimit = 50;
const _maximumAnalysisLimit = 200;

typedef McpSourceAuthorizer = FutureOr<bool> Function(
  RequestHandlerExtra extra,
  Set<String> requiredScopes,
);

List<McpToolDefinition> buildOverviewTools({
  required Mediator mediator,
  required McpSourceAuthorizer authorizeSources,
}) {
  final overview = _OverviewQueries(mediator);
  return [
    _tool(
      name: 'whph_overview_today',
      description: 'Returns task and habit summaries for one local calendar day.',
      inputSchema: _todaySchema(),
      requiredScopes: {McpScopes.overviewRead, McpScopes.tasksRead, McpScopes.habitsRead},
      handler: (arguments, extra) async => overview.day(_date(arguments, 'date')),
    ),
    _tool(
      name: 'whph_overview_calendar',
      description: 'Returns bounded task and habit completion summaries by local calendar day.',
      inputSchema: _rangeSchema(),
      requiredScopes: {McpScopes.overviewRead, McpScopes.tasksRead, McpScopes.habitsRead},
      handler: (arguments, extra) async {
        final range = _range(arguments, _maximumCalendarDays);
        final days = <Map<String, dynamic>>[];
        for (var day = range.start; day.isBefore(range.end); day = day.add(const Duration(days: 1))) {
          final summary = await overview.day(day, includeItems: false);
          days.add({'date': _dateOnly(day), ...summary});
        }
        return {'days': days};
      },
    ),
    _tool(
      name: 'whph_overview_time_analysis',
      description: 'Returns bounded element and tag time totals for explicitly authorized categories.',
      inputSchema: _analysisSchema(),
      requiredScopes: {McpScopes.overviewRead, McpScopes.tagsRead},
      handler: (arguments, extra) async {
        final range = _range(arguments, _maximumAnalysisDays);
        final categories = _categories(arguments);
        final sourceScopes = categories.map(_scopeForCategory).toSet();
        if (!await authorizeSources(extra, sourceScopes)) {
          throw McpToolException(McpToolError(
            code: McpToolErrorCode.permissionDenied,
            message: 'Every requested data category requires its read scope.',
          ));
        }
        final limit = arguments.optionalInt('limit') ?? _defaultAnalysisLimit;
        if (limit < 1 || limit > _maximumAnalysisLimit) {
          throw const FormatException('limit must be between 1 and 200.');
        }
        final tagIds = _strings(arguments, 'tagIds');
        final elements = await mediator.send<GetElementsByTimeQuery, GetElementsByTimeQueryResponse>(
          GetElementsByTimeQuery(
            startDate: range.start,
            endDate: range.end,
            limit: limit,
            filterByTags: tagIds,
            categories: categories,
          ),
        );
        final tags = await mediator.send<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse>(
          GetTopTagsByTimeQuery(
            startDate: range.start,
            endDate: range.end,
            limit: limit,
            filterByTags: tagIds,
            categories: categories,
          ),
        );
        return {
          'elements': elements.items
              .map((item) => {
                    'id': item.id,
                    'name': item.name,
                    'durationSeconds': item.duration,
                    'category': _categoryName(item.category),
                    'color': item.color,
                    'tag': item.tagId == null ? null : {'id': item.tagId, 'name': item.tagName, 'color': item.tagColor},
                  })
              .toList(growable: false),
          'tags': tags.items
              .map((item) => {
                    'id': item.tagId,
                    'name': item.tagName,
                    'color': item.tagColor,
                    'durationSeconds': item.duration,
                    'category': _categoryName(item.category),
                  })
              .toList(growable: false),
          'elementTotalDurationSeconds': elements.totalDuration,
          'tagTotalDurationSeconds': tags.totalDuration,
        };
      },
    ),
  ];
}

final class _OverviewQueries {
  const _OverviewQueries(this._mediator);

  final Mediator _mediator;

  Future<Map<String, dynamic>> day(DateTime date, {bool includeItems = true}) async {
    final end = date.add(const Duration(days: 1));
    final tasks = await _tasks(date, end);
    final habits = await _habits();
    final habitSummaries = <Map<String, dynamic>>[];
    var completedHabits = 0;
    var habitDuration = 0;
    for (final habit in habits) {
      final records = await _habitRecords(habit.id, date, end);
      final completedCount = records.where((record) => record.status == HabitRecordStatus.complete).length;
      if (completedCount > 0) completedHabits++;
      final duration = await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(
        GetTotalDurationByHabitIdQuery(habitId: habit.id, startDate: date, endDate: end),
      );
      habitDuration += duration.totalDuration;
      if (includeItems && habitSummaries.length < _queryPageSize) {
        habitSummaries.add({
          'id': habit.id,
          'name': habit.name,
          'type': habit.type.name,
          'completedCount': completedCount,
          'isCompleted': completedCount >= (habit.dailyTarget ?? 1),
          'durationSeconds': duration.totalDuration,
        });
      }
    }
    final completedTasks = tasks.where((task) => task.isCompleted).length;
    var taskDuration = 0;
    final taskDurations = <String, int>{};
    for (final task in tasks) {
      final duration = await _mediator.send<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse>(
        GetTotalDurationByTaskIdQuery(taskId: task.id, startDate: date, endDate: end),
      );
      taskDurations[task.id] = duration.totalDuration;
      taskDuration += duration.totalDuration;
    }
    return {
      'taskSummary': {
        'total': tasks.length,
        'completed': completedTasks,
        'durationSeconds': taskDuration,
      },
      'habitSummary': {
        'total': habits.length,
        'completed': completedHabits,
        'durationSeconds': habitDuration,
      },
      if (includeItems)
        'tasks': tasks
            .take(_queryPageSize)
            .map((task) => _taskJson(task, taskDurations[task.id] ?? 0))
            .toList(growable: false),
      if (includeItems) 'habits': habitSummaries,
      if (includeItems) 'isTruncated': tasks.length > _queryPageSize || habits.length > _queryPageSize,
    };
  }

  Future<List<TaskListItem>> _tasks(DateTime start, DateTime end) => _collectPages((pageIndex) async {
        final response = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
          GetListTasksQuery(
            pageIndex: pageIndex,
            pageSize: _queryPageSize,
            filterByPlannedStartDate: start,
            filterByPlannedEndDate: end,
            filterByDeadlineStartDate: start,
            filterByDeadlineEndDate: end,
            filterDateOr: true,
            includeNullDates: false,
            enableGrouping: false,
          ),
        );
        return (items: response.items, hasNext: response.hasNext);
      });

  Future<List<HabitListItem>> _habits() => _collectPages((pageIndex) async {
        final response = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
          GetListHabitsQuery(
            pageIndex: pageIndex,
            pageSize: _queryPageSize,
            filterByArchived: false,
          ),
        );
        return (items: response.items, hasNext: response.hasNext);
      });

  Future<List<HabitRecordListItem>> _habitRecords(String habitId, DateTime start, DateTime end) =>
      _collectPages((pageIndex) async {
        final response = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
          GetListHabitRecordsQuery(
            pageIndex: pageIndex,
            pageSize: _queryPageSize,
            habitId: habitId,
            startDate: start,
            endDate: end,
          ),
        );
        return (items: response.items, hasNext: response.hasNext);
      });
}

typedef _Page<T> = ({List<T> items, bool hasNext});

Future<List<T>> _collectPages<T>(Future<_Page<T>> Function(int pageIndex) load) async {
  final items = <T>[];
  for (var page = 0; items.length < _maximumAggregateItems; page++) {
    final response = await load(page);
    items.addAll(response.items);
    if (!response.hasNext) return List<T>.unmodifiable(items);
  }
  throw const FormatException('The aggregate contains too many records. Narrow the date range.');
}

typedef _OverviewHandler = Future<Map<String, dynamic>> Function(
  McpToolArguments arguments,
  RequestHandlerExtra extra,
);

McpToolDefinition _tool({
  required String name,
  required String description,
  required JsonObject inputSchema,
  required Set<String> requiredScopes,
  required _OverviewHandler handler,
}) =>
    McpToolDefinition(
      name: name,
      description: description,
      inputSchema: inputSchema,
      outputSchema: _overviewOutputSchema(name),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: requiredScopes,
      handler: (arguments, extra) async {
        try {
          return McpToolResult.success(await handler(arguments, extra));
        } on FormatException catch (error) {
          return McpToolResult.failure(McpToolError(
            code: McpToolErrorCode.validationError,
            message: error.message,
          ));
        }
      },
    );

JsonObject _overviewOutputSchema(String name) {
  final fields = switch (name) {
    'whph_overview_today' => ['taskSummary', 'habitSummary', 'tasks', 'habits', 'isTruncated'],
    'whph_overview_calendar' => ['days'],
    _ => ['elements', 'tags', 'elementTotalDurationSeconds', 'tagTotalDurationSeconds'],
  };
  return JsonSchema.object(
    properties: {for (final field in fields) field: JsonSchema.fromJson(const {})},
    additionalProperties: false,
  );
}

JsonObject _todaySchema() => JsonSchema.object(
      properties: {'date': JsonSchema.string(format: 'date')},
      required: ['date'],
      additionalProperties: false,
    );

JsonObject _rangeSchema() => JsonSchema.object(
      properties: {
        'from': JsonSchema.string(format: 'date'),
        'to': JsonSchema.string(format: 'date'),
      },
      required: ['from', 'to'],
      additionalProperties: false,
    );

JsonObject _analysisSchema() => JsonSchema.object(
      properties: {
        'from': JsonSchema.string(format: 'date'),
        'to': JsonSchema.string(format: 'date'),
        'categories': JsonSchema.array(
          items: JsonSchema.string(enumValues: ['tasks', 'habits', 'usage']),
          minItems: 1,
          uniqueItems: true,
        ),
        'tagIds': JsonSchema.array(items: JsonSchema.string()),
        'limit': JsonSchema.integer(minimum: 1, maximum: _maximumAnalysisLimit),
      },
      required: ['from', 'to', 'categories'],
      additionalProperties: false,
    );

({DateTime start, DateTime end}) _range(McpToolArguments arguments, int maximumDays) {
  final start = _date(arguments, 'from');
  final end = _date(arguments, 'to').add(const Duration(days: 1));
  if (!end.isAfter(start) || end.difference(start).inDays > maximumDays) {
    throw FormatException('The date range must be ordered and no longer than $maximumDays days.');
  }
  return (start: start, end: end);
}

DateTime _date(McpToolArguments arguments, String field) {
  final value = arguments.requireString(field);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) throw FormatException('$field must be YYYY-MM-DD.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _dateOnly(parsed) != value) throw FormatException('$field is invalid.');
  return parsed;
}

List<TagTimeCategory> _categories(McpToolArguments arguments) {
  final values = arguments.optionalList('categories') ?? const [];
  return List<TagTimeCategory>.unmodifiable(values.map((value) {
    if (value is! String) throw const FormatException('categories must contain strings.');
    return switch (value) {
      'tasks' => TagTimeCategory.tasks,
      'habits' => TagTimeCategory.habits,
      'usage' => TagTimeCategory.appUsage,
      _ => throw const FormatException('Unknown analysis category.'),
    };
  }));
}

List<String>? _strings(McpToolArguments arguments, String field) {
  final values = arguments.optionalList(field);
  if (values == null) return null;
  if (values.any((value) => value is! String || value.isEmpty)) throw FormatException('$field must contain strings.');
  return List<String>.unmodifiable(values.cast<String>());
}

String _scopeForCategory(TagTimeCategory category) => switch (category) {
      TagTimeCategory.tasks => McpScopes.tasksRead,
      TagTimeCategory.habits => McpScopes.habitsRead,
      TagTimeCategory.appUsage => McpScopes.usageRead,
      TagTimeCategory.all => throw StateError('The all category is not accepted.'),
    };

String _categoryName(TagTimeCategory category) => switch (category) {
      TagTimeCategory.tasks => 'tasks',
      TagTimeCategory.habits => 'habits',
      TagTimeCategory.appUsage => 'usage',
      TagTimeCategory.all => 'all',
    };

Map<String, dynamic> _taskJson(TaskListItem task, int durationSeconds) => {
      'id': task.id,
      'title': task.title,
      'isCompleted': task.isCompleted,
      'plannedAt': task.plannedDate?.toIso8601String(),
      'deadlineAt': task.deadlineDate?.toIso8601String(),
      'durationSeconds': durationSeconds,
    };

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
