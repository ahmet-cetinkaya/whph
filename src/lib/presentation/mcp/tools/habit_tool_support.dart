part of 'habit_tools.dart';

CallToolResult _failure(McpToolErrorCode code, String message) =>
    McpToolResult.failure(McpToolError(code: code, message: message));

Map<String, dynamic> _habitResult(GetHabitQueryResponse habit) => {
      'id': habit.id,
      'name': habit.name,
      'description': habit.description,
      'type': habit.type.name,
      'estimatedMinutes': habit.estimatedTime,
      'hasReminder': habit.hasReminder,
      'reminderTime': habit.reminderTime,
      'reminderDays': habit.getReminderDaysAsList(),
      'hasGoal': habit.hasGoal,
      'targetFrequency': habit.targetFrequency,
      'periodDays': habit.periodDays,
      'dailyTarget': habit.dailyTarget,
      'isArchived': habit.isArchived,
      'archivedAt': habit.archivedDate == null ? null : _iso(habit.archivedDate!),
      'createdAt': _iso(habit.createdDate),
      'revision': _iso(_entityRevision(habit)),
    };

Map<String, dynamic> _statisticsJson(HabitStatistics statistics) => {
      'overallScore': statistics.overallScore,
      'monthlyScore': statistics.monthlyScore,
      'yearlyScore': statistics.yearlyScore,
      'totalRecords': statistics.totalRecords,
      'monthlyScores':
          statistics.monthlyScores.map((entry) => {'month': _date(entry.key), 'score': entry.value}).toList(),
      'topStreaks': statistics.topStreaks
          .map((streak) => {
                'startDate': _date(streak.startDate),
                'endDate': _date(streak.endDate),
                'days': streak.days,
                'completions': streak.completions,
              })
          .toList(),
      'yearlyFrequency':
          statistics.yearlyFrequency.entries.map((entry) => {'dayOfYear': entry.key, 'count': entry.value}).toList(),
      'goalSuccessRate': statistics.goalSuccessRate,
      'daysGoalMet': statistics.daysGoalMet,
      'totalDaysWithGoal': statistics.totalDaysWithGoal,
    };

HabitValues _createValues(McpToolArguments arguments) {
  final type = _type(arguments.requireString('type'));
  final name = arguments.requireString('name').trim();
  if (name.isEmpty) _invalid('name', 'must not be empty');
  return _validatedValues(HabitValues(
    name: name,
    description: arguments.optionalString('description') ?? '',
    type: type,
    estimatedTime: arguments.optionalInt('estimatedMinutes'),
    hasReminder: arguments.optionalBool('hasReminder') ?? false,
    reminderTime: arguments.optionalString('reminderTime'),
    reminderDays: _ints(arguments, 'reminderDays') ?? const [],
    hasGoal: arguments.optionalBool('hasGoal') ?? false,
    targetFrequency: arguments.optionalInt('targetFrequency') ?? 1,
    periodDays: arguments.optionalInt('periodDays') ?? 1,
    dailyTarget: arguments.optionalInt('dailyTarget'),
    archivedDate: null,
    order: OrderRank.initialRank,
  ));
}

HabitValues _updatedValues(HabitValues current, McpToolArguments arguments) => _validatedValues(HabitValues(
      name: arguments.contains('name') ? arguments.requireString('name').trim() : current.name,
      description: arguments.contains('description') ? arguments.requireString('description') : current.description,
      type: arguments.contains('type') ? _type(arguments.requireString('type')) : current.type,
      estimatedTime:
          arguments.contains('estimatedMinutes') ? arguments.optionalInt('estimatedMinutes') : current.estimatedTime,
      hasReminder: arguments.contains('hasReminder') ? _requiredBool(arguments, 'hasReminder') : current.hasReminder,
      reminderTime:
          arguments.contains('reminderTime') ? arguments.optionalString('reminderTime') : current.reminderTime,
      reminderDays:
          arguments.contains('reminderDays') ? (_ints(arguments, 'reminderDays') ?? const []) : current.reminderDays,
      hasGoal: arguments.contains('hasGoal') ? _requiredBool(arguments, 'hasGoal') : current.hasGoal,
      targetFrequency: arguments.contains('targetFrequency')
          ? _requiredInt(arguments, 'targetFrequency', minimum: 1)
          : current.targetFrequency,
      periodDays:
          arguments.contains('periodDays') ? _requiredInt(arguments, 'periodDays', minimum: 1) : current.periodDays,
      dailyTarget: arguments.contains('dailyTarget') ? arguments.optionalInt('dailyTarget') : current.dailyTarget,
      archivedDate: current.archivedDate,
      order: current.order,
    ));

HabitValues _validatedValues(HabitValues values) {
  if (values.name.isEmpty) _invalid('name', 'must not be empty');
  if (values.estimatedTime != null && values.estimatedTime! < 0) _invalid('estimatedMinutes', 'must not be negative');
  if (values.targetFrequency < 1) _invalid('targetFrequency', 'must be positive');
  if (values.periodDays < 1) _invalid('periodDays', 'must be positive');
  if (values.dailyTarget != null && values.dailyTarget! < 1) _invalid('dailyTarget', 'must be positive');
  if (values.reminderTime != null && !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(values.reminderTime!)) {
    _invalid('reminderTime', 'must be HH:mm');
  }
  if (values.reminderDays.any((day) => day < 1 || day > 7) ||
      values.reminderDays.toSet().length != values.reminderDays.length) {
    _invalid('reminderDays', 'must contain unique weekdays 1 through 7');
  }
  return values;
}

HabitType _type(String value) => switch (value) {
      'good' => HabitType.good,
      'bad' => HabitType.bad,
      _ => throw _validation('type', 'must be good or bad'),
    };

HabitRecordStatus _status(String value) => switch (value) {
      'complete' => HabitRecordStatus.complete,
      'not_done' => HabitRecordStatus.notDone,
      'skipped' => HabitRecordStatus.skipped,
      _ => throw _validation('status', 'must be complete, not_done, or skipped'),
    };

({int pageIndex, int pageSize}) _pagination(McpToolArguments arguments) {
  final size = arguments.optionalInt('pageSize') ?? _defaultPageSize;
  if (size < 1 || size > _maximumPageSize) _invalid('pageSize', 'must be between 1 and 200');
  final cursor = arguments.optionalString('cursor');
  final page = cursor == null ? 0 : int.tryParse(cursor);
  if (page == null || page < 0) _invalid('cursor', 'must be a non-negative page cursor');
  return (pageIndex: page, pageSize: size);
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items, int total, ({int pageIndex, int pageSize}) page) => {
      'items': items,
      'totalItemCount': total,
      'nextCursor': (page.pageIndex + 1) * page.pageSize < total ? '${page.pageIndex + 1}' : null,
    };

({DateTime start, DateTime end}) _range(McpToolArguments arguments) {
  final from = _localDate(arguments.requireString('from'));
  final to = _localDate(arguments.requireString('to'));
  if (to.isBefore(from)) _invalid('to', 'must not be before from');
  return (start: HabitDayStateResolver.utcRangeFor(from).start, end: HabitDayStateResolver.utcRangeFor(to).end);
}

({DateTime? start, DateTime? end})? _optionalTimeRange(McpToolArguments arguments) {
  final from = arguments.optionalString('from');
  final to = arguments.optionalString('to');
  if (from == null && to == null) return null;
  final start = from == null ? null : _instant(from);
  final end = to == null ? null : _instant(to);
  if (start != null && end != null && end.isBefore(start)) _invalid('to', 'must not be before from');
  return (start: start, end: end);
}

bool _inRange(DateTime value, ({DateTime? start, DateTime? end})? range) =>
    range == null ||
    (range.start == null || !value.isBefore(range.start!)) && (range.end == null || !value.isAfter(range.end!));

DateTime _localDate(String value) {
  if (!RegExp(_datePattern).hasMatch(value)) _invalid('date', 'must use YYYY-MM-DD');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _date(parsed) != value) _invalid('date', 'is not a valid calendar date');
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _instant(String value) {
  if (!RegExp(_revisionPattern).hasMatch(value)) _invalid('dateTime', 'must include a UTC or numeric offset');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) _invalid('dateTime', 'must be ISO-8601');
  return parsed.toUtc();
}

DateTime _revision(String value) => _instant(value);

int _requiredInt(McpToolArguments arguments, String name, {int? minimum}) {
  final value = arguments.optionalInt(name);
  if (value == null) _invalid(name, 'is required');
  if (minimum != null && value < minimum) _invalid(name, 'must be at least $minimum');
  return value;
}

bool _requiredBool(McpToolArguments arguments, String name) {
  final value = arguments.optionalBool(name);
  if (value == null) _invalid(name, 'is required');
  return value;
}

List<String>? _strings(McpToolArguments arguments, String name) {
  final values = arguments.optionalList(name);
  if (values == null) return null;
  if (values.any((value) => value is! String)) _invalid(name, 'must contain strings');
  return List<String>.unmodifiable(values.cast<String>());
}

List<int>? _ints(McpToolArguments arguments, String name) {
  final values = arguments.optionalList(name);
  if (values == null) return null;
  if (values.any((value) => value is! int)) _invalid(name, 'must contain integers');
  return List<int>.unmodifiable(values.cast<int>());
}

Map<String, int>? _tagOrder(McpToolArguments arguments) {
  final ids = _strings(arguments, 'tagOrder');
  if (ids == null) return null;
  if (ids.toSet().length != ids.length) _invalid('tagOrder', 'must contain unique tag ids');
  return {for (var index = 0; index < ids.length; index++) ids[index]: index};
}

List<SortOption<HabitSortFields>>? _sort(String? value) {
  if (value == null || value == 'custom') return null;
  final parts = value.split('_');
  final direction = parts.last == 'desc' ? SortDirection.desc : SortDirection.asc;
  final fieldName = parts.last == 'asc' || parts.last == 'desc' ? parts.take(parts.length - 1).join('_') : value;
  final field = _sortField(fieldName);
  return [SortOption(field: field, direction: direction)];
}

SortOption<HabitSortFields>? _group(String? value) => value == null ? null : SortOption(field: _sortField(value));

HabitSortFields _sortField(String value) => switch (value) {
      'name' => HabitSortFields.name,
      'createdDate' || 'created_date' => HabitSortFields.createdDate,
      'modifiedDate' || 'modified_date' => HabitSortFields.modifiedDate,
      'estimatedMinutes' || 'estimated_time' => HabitSortFields.estimatedTime,
      'totalDuration' || 'actual_time' => HabitSortFields.actualTime,
      'archivedDate' || 'archived_date' => HabitSortFields.archivedDate,
      'tag' => HabitSortFields.tag,
      _ => throw _validation('sort', 'contains an unknown field'),
    };

Never _invalid(String field, String reason) => throw _validation(field, reason);

McpToolException _validation(String field, String reason) => McpToolException(McpToolError(
      code: McpToolErrorCode.validationError,
      message: 'Argument "$field" $reason.',
      details: {'field': field},
    ));

DateTime _entityRevision(BaseEntity<String> entity) => DateTime.fromMillisecondsSinceEpoch(
      (entity.modifiedDate ?? entity.createdDate).toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );

DateTime _timeOf(HabitTimeRecord record) => (record.occurredAt ?? record.createdDate).toUtc();
String _iso(DateTime value) => value.toUtc().toIso8601String();
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
