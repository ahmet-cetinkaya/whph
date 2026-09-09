import 'package:acore/acore.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/habits/services/habit_actions.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

part 'habit_tool_contract.dart';
part 'habit_tool_support.dart';

const _defaultPageSize = 50;
const _maximumPageSize = 200;
const _datePattern = r'^\d{4}-\d{2}-\d{2}$';
const _revisionPattern = r'(Z|[+-]\d{2}:\d{2})$';

typedef McpHabitCommitGuard = Future<bool> Function(
  RequestHandlerExtra extra,
  Set<String> scopes,
);

List<McpToolDefinition> buildHabitTools({
  required Mediator mediator,
  required HabitActions actions,
  required IHabitRepository habitRepository,
  required IHabitRecordRepository habitRecordRepository,
  required IHabitTimeRecordRepository habitTimeRecordRepository,
  required McpHabitCommitGuard authorizeBeforeCommit,
}) =>
    _HabitTools(
      mediator: mediator,
      actions: actions,
      habitRepository: habitRepository,
      habitRecordRepository: habitRecordRepository,
      habitTimeRecordRepository: habitTimeRecordRepository,
      authorizeBeforeCommit: authorizeBeforeCommit,
    ).definitions;

final class _HabitTools {
  const _HabitTools({
    required this.mediator,
    required this.actions,
    required this.habitRepository,
    required this.habitRecordRepository,
    required this.habitTimeRecordRepository,
    required this.authorizeBeforeCommit,
  });

  final Mediator mediator;
  final HabitActions actions;
  final IHabitRepository habitRepository;
  final IHabitRecordRepository habitRecordRepository;
  final IHabitTimeRecordRepository habitTimeRecordRepository;
  final McpHabitCommitGuard authorizeBeforeCommit;

  List<McpToolDefinition> get definitions => [
        _tool('whph_habits_list', 'Lists habits with filters, tags, and daily state.', _listInput, _habitListOutput,
            const {McpScopes.habitsRead, McpScopes.tagsRead}, _read, _list),
        _tool('whph_habits_read', 'Reads one habit including reminder and goal fields.', _idInput, _habitReadOutput,
            const {McpScopes.habitsRead}, _read, _readHabit),
        _tool('whph_habits_create', 'Creates a good or bad habit and refreshes reminders.', _createInput,
            _revisionOutput, const {McpScopes.habitsWrite, McpScopes.tagsWrite}, _add, _create),
        _tool('whph_habits_update', 'Updates supplied habit fields and preserves omitted fields.', _updateInput,
            _revisionOutput, const {McpScopes.habitsWrite, McpScopes.tagsWrite}, _mutate, _update),
        _tool('whph_habits_archive', 'Explicitly archives or restores a habit.', _archiveInput, _archiveOutput,
            const {McpScopes.habitsWrite}, _mutate, _archive),
        _tool('whph_habits_delete', 'Deletes a habit and its related records.', _revisionInput, _deleteOutput,
            const {McpScopes.habitsDelete}, _destroy, _delete),
        _tool('whph_habits_reorder', 'Moves a habit to an explicit list position.', _reorderInput, _orderOutput,
            const {McpScopes.habitsWrite}, _mutate, _reorder),
        _tool('whph_habit_records_list', 'Lists dated habit records.', _recordListInput, _recordListOutput,
            const {McpScopes.habitsRead}, _read, _listRecords),
        _tool('whph_habit_records_set', 'Sets an explicit complete, not_done, or skipped daily state.', _recordSetInput,
            _recordSetOutput, const {McpScopes.habitsWrite}, _mutate, _setRecords),
        _tool('whph_habit_records_undo', 'Removes the addressed or latest record for a date.', _recordUndoInput,
            _undoOutput, const {McpScopes.habitsWrite}, _destroy, _undoRecord),
        _tool('whph_habit_daily_results', 'Returns per-day outcomes and a range summary.', _rangeInput, _dailyOutput,
            const {McpScopes.habitsRead}, _read, _dailyResults),
        _tool('whph_habit_statistics', 'Returns scores, streaks, frequency, and goal statistics.', _idInput,
            _statisticsOutput, const {McpScopes.habitsRead}, _read, _statistics),
        _tool('whph_habit_time_records_list', 'Lists habit time records and their total.', _timeListInput,
            _timeListOutput, const {McpScopes.habitsRead, McpScopes.timersRead}, _read, _listTimeRecords),
        _tool('whph_habit_time_records_add', 'Adds a positive duration to a habit.', _timeAddInput, _idOnlyOutput,
            const {McpScopes.habitsWrite, McpScopes.timersWrite}, _add, _addTimeRecord),
        _tool('whph_habit_time_records_update', 'Replaces a dated time total after a revision check.', _timeUpdateInput,
            _revisionOutput, const {McpScopes.habitsWrite, McpScopes.timersWrite}, _mutate, _updateTimeRecord),
        _tool('whph_habit_time_total', 'Returns total habit duration for an optional range.', _timeListInput,
            _totalOutput, const {McpScopes.habitsRead, McpScopes.timersRead}, _read, _timeTotal),
      ];

  Future<CallToolResult> _list(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final pagination = _pagination(arguments);
        final response = await mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(GetListHabitsQuery(
          pageIndex: pagination.pageIndex,
          pageSize: pagination.pageSize,
          search: arguments.optionalString('search'),
          filterByTags: _strings(arguments, 'tagIds'),
          filterNoTags: arguments.optionalBool('withoutTags') ?? false,
          filterByArchived: arguments.optionalBool('isArchived'),
          excludeCompleted: arguments.optionalBool('excludeCompleted') ?? false,
          excludeCompletedForDate:
              arguments.contains('forDate') ? _localDate(arguments.requireString('forDate')) : null,
          sortBy: _sort(arguments.optionalString('sort')),
          sortByCustomSort: arguments.optionalString('sort') == null || arguments.optionalString('sort') == 'custom',
          groupBy: _group(arguments.optionalString('groupBy')),
          customTagSortOrder: _strings(arguments, 'customTagOrder'),
          ignoreArchivedTagVisibility: arguments.optionalBool('includeArchivedTags') ?? false,
        ));
        final forDate = arguments.contains('forDate') ? _localDate(arguments.requireString('forDate')) : DateTime.now();
        final durations = await habitTimeRecordRepository
            .getTotalDurationsByHabitIds(response.items.map((habit) => habit.id).toList());
        final items = <Map<String, dynamic>>[];
        for (final habit in response.items) {
          final range = HabitDayStateResolver.utcRangeFor(forDate);
          final records =
              await habitRecordRepository.getListByHabitIdAndRangeDate(habit.id, range.start, range.end, 0, 1000);
          final entity = await habitRepository.getById(habit.id);
          final state = entity == null
              ? HabitDayState.notApplicable
              : const HabitDayStateResolver()
                  .createSource(habit: entity, records: records.items, now: DateTime.now())
                  .resolve(forDate);
          items.add({
            'id': habit.id,
            'name': habit.name,
            'type': habit.type.name,
            'estimatedMinutes': habit.estimatedTime,
            'totalDurationSeconds': durations[habit.id] ?? 0,
            'isArchived': habit.isArchived,
            'dailyState': state.name,
            'tags': habit.tags.map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color}).toList(),
          });
        }
        return _page(items, response.totalItemCount, pagination);
      });

  Future<CallToolResult> _readHabit(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final habit = await _getHabit(arguments.requireString('id'));
        final persisted = await _requireHabit(habit.id);
        return {..._habitResult(habit), 'order': persisted.order};
      });

  Future<CallToolResult> _create(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final values = _createValues(arguments);
        final result = await actions.create(
          values,
          _strings(arguments, 'tagIds') ?? const [],
          () => _commitGuard(extra, const {McpScopes.habitsWrite, McpScopes.tagsWrite}),
        );
        return {'id': result.id, 'revision': _iso(result.revision)};
      });

  Future<CallToolResult> _update(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final result = await actions.update(
          id: arguments.requireString('id'),
          expectedRevision: _revision(arguments.requireString('expectedRevision')),
          updateValues: (current) => _updatedValues(current, arguments),
          tagIds: _strings(arguments, 'tagIds'),
          tagOrder: _tagOrder(arguments),
          beforeCommit: () => _commitGuard(extra, const {McpScopes.habitsWrite, McpScopes.tagsWrite}),
        );
        return {'id': result.id, 'revision': _iso(result.revision)};
      });

  Future<CallToolResult> _archive(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final isArchived = _requiredBool(arguments, 'isArchived');
        final result = await actions.archive(
          arguments.requireString('id'),
          _revision(arguments.requireString('expectedRevision')),
          isArchived,
          () => _commitGuard(extra, const {McpScopes.habitsWrite}),
        );
        return {'id': result.id, 'isArchived': isArchived, 'revision': _iso(result.revision)};
      });

  Future<CallToolResult> _delete(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final id = arguments.requireString('id');
        final deletedAt = await actions.delete(
          id,
          _revision(arguments.requireString('expectedRevision')),
          () => _commitGuard(extra, const {McpScopes.habitsDelete}),
        );
        return {'id': id, 'deletedAt': _iso(deletedAt)};
      });

  Future<CallToolResult> _reorder(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final result = await actions.reorder(
          id: arguments.requireString('id'),
          expectedRevision: _revision(arguments.requireString('expectedRevision')),
          targetIndex: _requiredInt(arguments, 'targetIndex', minimum: 0),
          beforeId: arguments.optionalString('beforeId'),
          afterId: arguments.optionalString('afterId'),
          beforeCommit: () => _commitGuard(extra, const {McpScopes.habitsWrite}),
        );
        final habit = await habitRepository.getById(result.id);
        return {'id': result.id, 'order': habit!.order, 'revision': _iso(result.revision)};
      });

  Future<CallToolResult> _listRecords(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final id = arguments.requireString('habitId');
        await _requireHabit(id);
        final pagination = _pagination(arguments);
        final range = _range(arguments);
        final response = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
          GetListHabitRecordsQuery(
              pageIndex: pagination.pageIndex,
              pageSize: pagination.pageSize,
              habitId: id,
              startDate: range.start,
              endDate: range.end),
        );
        final records = response.items.toList()
          ..sort((left, right) {
            final date = left.occurredAt.compareTo(right.occurredAt);
            return date != 0 ? date : left.id.compareTo(right.id);
          });
        return _page(
            records
                .map((record) => {
                      'id': record.id,
                      'date': _date(record.date),
                      'occurredAt': _iso(record.occurredAt),
                      'status': record.status.value,
                    })
                .toList(),
            response.totalItemCount,
            pagination);
      });

  Future<CallToolResult> _setRecords(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final status = _status(arguments.requireString('status'));
        final count = arguments.optionalInt('count') ?? 1;
        if (count < 0) _invalid('count', 'must not be negative');
        if (status == HabitRecordStatus.complete && count == 0) {
          _invalid('count', 'must be positive for complete records');
        }
        final result = await actions.setRecords(
          habitId: arguments.requireString('habitId'),
          date: _localDate(arguments.requireString('date')),
          status: status,
          count: count,
          beforeCommit: (requiresTimerWrite) => _commitGuard(extra, {
            McpScopes.habitsWrite,
            if (requiresTimerWrite) McpScopes.timersWrite,
          }),
        );
        return {
          'habitId': arguments.requireString('habitId'),
          'date': arguments.requireString('date'),
          'status': result.status.value,
          'count': result.count,
        };
      });

  Future<CallToolResult> _undoRecord(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final result = await actions.undoRecord(
          habitId: arguments.requireString('habitId'),
          date: _localDate(arguments.requireString('date')),
          recordId: arguments.optionalString('recordId'),
          beforeCommit: () => _commitGuard(extra, const {McpScopes.habitsWrite}),
        );
        return {
          'habitId': arguments.requireString('habitId'),
          'date': arguments.requireString('date'),
          'remainingCount': result.remainingCount,
        };
      });

  Future<CallToolResult> _dailyResults(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final id = arguments.requireString('habitId');
        final habit = await _requireHabit(id);
        final range = _range(arguments);
        final records = await habitRecordRepository.getListByHabitIdAndRangeDate(id, range.start, range.end, 0, 100000);
        final source =
            const HabitDayStateResolver().createSource(habit: habit, records: records.items, now: DateTime.now());
        final days = <Map<String, dynamic>>[];
        var cursor = _localDate(arguments.requireString('from'));
        final last = _localDate(arguments.requireString('to'));
        final counts = <String, int>{};
        while (!cursor.isAfter(last)) {
          final dayRange = HabitDayStateResolver.utcRangeFor(cursor);
          final count = records.items
              .where((record) =>
                  !record.occurredAt.isBefore(dayRange.start) &&
                  !record.occurredAt.isAfter(dayRange.end) &&
                  record.status == HabitRecordStatus.complete)
              .length;
          final state = source.resolve(cursor).name;
          counts[state] = (counts[state] ?? 0) + 1;
          days.add({'date': _date(cursor), 'status': state, 'count': count, 'target': habit.getDailyTarget()});
          cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        }
        return {'days': days, 'summary': counts};
      });

  Future<CallToolResult> _statistics(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final habit = await _getHabit(arguments.requireString('id'));
        return _statisticsJson(habit.statistics);
      });

  Future<CallToolResult> _listTimeRecords(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final id = arguments.requireString('habitId');
        await _requireHabit(id);
        final range = _optionalTimeRange(arguments);
        final all = await habitTimeRecordRepository.getByHabitId(id);
        final records = all.where((record) => _inRange(_timeOf(record), range)).toList()
          ..sort((left, right) {
            final occurred = _timeOf(left).compareTo(_timeOf(right));
            return occurred != 0 ? occurred : left.id.compareTo(right.id);
          });
        return {
          'items': records
              .map((record) => {
                    'id': record.id,
                    'occurredAt': _iso(_timeOf(record)),
                    'durationSeconds': record.duration,
                    'revision': _iso(_entityRevision(record)),
                  })
              .toList(),
          'totalDurationSeconds': records.fold<int>(0, (total, record) => total + record.duration),
        };
      });

  Future<CallToolResult> _addTimeRecord(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final duration = _requiredInt(arguments, 'durationSeconds', minimum: 1);
        final occurredAt =
            arguments.contains('occurredAt') ? _instant(arguments.requireString('occurredAt')) : DateTime.now().toUtc();
        final result = await actions.addTimeRecord(
          habitId: arguments.requireString('habitId'),
          occurredAt: occurredAt,
          duration: duration,
          beforeCommit: () => _commitGuard(extra, const {McpScopes.habitsWrite, McpScopes.timersWrite}),
        );
        return {'id': result.id};
      });

  Future<CallToolResult> _updateTimeRecord(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final result = await actions.updateTimeRecord(
          habitId: arguments.requireString('habitId'),
          date: _localDate(arguments.requireString('date')),
          totalDuration: _requiredInt(arguments, 'totalDurationSeconds', minimum: 0),
          expectedRevision: _revision(arguments.requireString('expectedRevision')),
          beforeCommit: () => _commitGuard(extra, const {McpScopes.habitsWrite, McpScopes.timersWrite}),
        );
        return {'id': result.id, 'revision': _iso(result.revision)};
      });

  Future<CallToolResult> _timeTotal(McpToolArguments arguments, RequestHandlerExtra extra) => _guard(() async {
        final id = arguments.requireString('habitId');
        await _requireHabit(id);
        final range = _optionalTimeRange(arguments);
        final response = await mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(
          GetTotalDurationByHabitIdQuery(habitId: id, startDate: range?.start, endDate: range?.end),
        );
        return {'totalDurationSeconds': response.totalDuration};
      });

  Future<GetHabitQueryResponse> _getHabit(String id) async {
    try {
      return await mediator.send<GetHabitQuery, GetHabitQueryResponse>(GetHabitQuery(id: id));
    } on BusinessException {
      throw HabitNotFoundException(id);
    }
  }

  Future<Habit> _requireHabit(String id) async {
    final habit = await habitRepository.getById(id);
    if (habit == null) throw HabitNotFoundException(id);
    return habit;
  }

  Future<void> _commitGuard(RequestHandlerExtra extra, Set<String> scopes) async {
    if (!await authorizeBeforeCommit(extra, scopes)) {
      throw McpToolException(McpToolError(
        code: McpToolErrorCode.permissionDenied,
        message: 'The connection is no longer permitted to commit this operation.',
      ));
    }
  }
}

McpToolDefinition _tool(
  String name,
  String description,
  JsonObject input,
  JsonObject output,
  Set<String> scopes,
  ToolAnnotations annotations,
  McpToolHandler handler,
) =>
    McpToolDefinition(
      name: name,
      description: description,
      inputSchema: input,
      outputSchema: output,
      requiredScopes: scopes,
      annotations: annotations,
      handler: handler,
    );

Future<CallToolResult> _guard(Future<Map<String, dynamic>> Function() operation) async {
  try {
    return McpToolResult.success(await operation());
  } on McpToolException catch (error) {
    return McpToolResult.failure(error.error);
  } on HabitNotFoundException {
    return _failure(McpToolErrorCode.notFound, 'The habit was not found.');
  } on HabitRecordNotFoundException {
    return _failure(McpToolErrorCode.notFound, 'The habit record was not found.');
  } on HabitTimeRecordNotFoundException {
    return _failure(McpToolErrorCode.notFound, 'The habit time record was not found.');
  } on HabitTagNotFoundException {
    return _failure(McpToolErrorCode.notFound, 'A requested tag was not found.');
  } on HabitRevisionConflictException {
    return _failure(McpToolErrorCode.conflict, 'The habit changed since it was read.');
  } on BusinessException {
    return _failure(McpToolErrorCode.validationError, 'The habit operation is not valid.');
  } on ArgumentError {
    return _failure(McpToolErrorCode.validationError, 'The supplied habit values are not valid.');
  } catch (_) {
    return _failure(McpToolErrorCode.operationFailed, 'The habit operation failed.');
  }
}
