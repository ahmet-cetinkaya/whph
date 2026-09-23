part of 'task_tools.dart';

int _pageSize(McpToolArguments args) => args.optionalInt('pageSize') ?? 50;
int _cursor(McpToolArguments args) => int.tryParse(args.optionalString('cursor') ?? '0') ?? 0;
Map<String, dynamic> _page(List<Map<String, dynamic>> items, int total, int page, int size) =>
    {'items': items, 'totalCount': total, 'nextCursor': (page + 1) * size < total ? '${page + 1}' : null};
Map<String, dynamic> _taskSummary(TaskListItem task) => {
      'id': task.id,
      'title': task.title,
      'priority': task.priority?.name,
      'plannedAt': task.plannedDate?.toIso8601String(),
      'deadlineAt': task.deadlineDate?.toIso8601String(),
      'completedAt': task.completedAt?.toIso8601String(),
      'isCompleted': task.isCompleted,
      'statusId': task.statusId,
      'parentId': task.parentTaskId,
      'estimatedMinutes': task.estimatedTime,
      'totalDurationSeconds': task.totalElapsedTime,
      'order': task.order,
      'tags': task.tags
          .map((tag) => {'id': tag.id, 'name': tag.name, 'color': tag.color, 'type': tag.type.name, 'order': 0})
          .toList(),
      'revision': _iso(task.modifiedDate ?? task.createdDate!)
    };
Map<String, dynamic> _taskMap(Task task) => {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'priority': task.priority?.name,
      'plannedAt': task.plannedDate?.toIso8601String(),
      'deadlineAt': task.deadlineDate?.toIso8601String(),
      'completedAt': task.completedAt?.toIso8601String(),
      'isCompleted': task.isCompleted,
      'statusId': task.statusId,
      'parentId': task.parentTaskId,
      'estimatedMinutes': task.estimatedTime,
      'order': task.order,
      'plannedReminder': {
        'time': task.plannedDateReminderTime.name,
        if (task.plannedDateReminderCustomOffset != null) 'customOffsetMinutes': task.plannedDateReminderCustomOffset,
      },
      'deadlineReminder': {
        'time': task.deadlineDateReminderTime.name,
        if (task.deadlineDateReminderCustomOffset != null) 'customOffsetMinutes': task.deadlineDateReminderCustomOffset,
      },
      'recurrence': {
        'type': task.recurrenceType.name,
        if (task.recurrenceInterval != null) 'interval': task.recurrenceInterval,
        if (task.recurrenceDaysString != null) 'days': task.recurrenceDaysString!.split(','),
        if (task.recurrenceStartDate != null) 'startAt': _iso(task.recurrenceStartDate!),
        if (task.recurrenceEndDate != null) 'endAt': _iso(task.recurrenceEndDate!),
        if (task.recurrenceCount != null) 'count': task.recurrenceCount,
      },
      'revision': _revision(task)
    };
String _revision(Task task) => _iso(task.modifiedDate ?? task.createdDate);
String _iso(DateTime value) => value.toUtc().toIso8601String();
DateTime _requiredRevision(McpToolArguments args) =>
    _parseInstant(args.requireString('expectedRevision'), 'expectedRevision');
DateTime? _optionalInstant(McpToolArguments args, String name) =>
    args.contains(name) ? _nullableInstant(args, name) : null;
DateTime? _nullableInstant(McpToolArguments args, String name) {
  final value = args[name];
  if (value == null) return null;
  if (value is! String) throw _validation(name, 'must be an offset date-time');
  return _parseInstant(value, name);
}

DateTime _parseInstant(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value))
    throw _validation(field, 'must include an offset');
  return parsed.toUtc();
}

DateTime _dateOnly(String value, String field) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw _validation(field, 'must use YYYY-MM-DD');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw _validation(field, 'must be a real calendar date');
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

List<String>? _stringList(McpToolArguments args, String name) {
  final values = args.optionalList(name);
  if (values == null) return null;
  if (values.any((value) => value is! String)) throw _validation(name, 'must contain strings');
  final strings = values.cast<String>();
  if (strings.toSet().length != strings.length) throw _validation(name, 'must not contain duplicates');
  return List.unmodifiable(strings);
}

List<SortOption<TaskSortFields>>? _sort(List<dynamic>? raw) => raw?.map((value) {
      if (value is! Map<String, dynamic>) throw _validation('sort', 'must contain objects');
      return _sortOne(value)!;
    }).toList();
SortOption<TaskSortFields>? _sortOne(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  return SortOption(
      field: _enum(raw['field'] as String?, TaskSortFields.values)!,
      direction: raw['direction'] == 'desc' ? SortDirection.desc : SortDirection.asc);
}

T? _enum<T extends Enum>(String? value, List<T> values) {
  if (value == null) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw _validation('enum', 'has an unknown value');
}

ReminderTime? _reminder(Map<String, dynamic>? raw) =>
    raw == null ? null : _enum(raw['time'] as String?, ReminderTime.values);
int? _reminderOffset(Map<String, dynamic>? raw) => raw?['customOffsetMinutes'] as int?;
Map<String, dynamic>? _recurrence(McpToolArguments args) => args.optionalObject('recurrence');
RecurrenceType? _recurrenceType(Map<String, dynamic>? raw) =>
    raw == null ? null : _enum(raw['type'] as String?, RecurrenceType.values);
int? _recurrenceInt(McpToolArguments args, String name) => _recurrence(args)?[name] as int?;
DateTime? _recurrenceDate(McpToolArguments args, String name) {
  final value = _recurrence(args)?[name];
  return value == null ? null : _parseInstant(value as String, 'recurrence.$name');
}

List<WeekDays>? _recurrenceDays(McpToolArguments args) {
  final values = _recurrence(args)?['days'] as List<dynamic>?;
  return values?.map((value) => _enum(value as String, WeekDays.values)!).toList();
}

void _addRecurrencePatch(Map<String, Object?> patch, Map<String, dynamic>? raw) {
  if (raw == null) {
    patch['recurrenceType'] = RecurrenceType.none;
    patch['recurrenceInterval'] = null;
    patch['recurrenceDays'] = null;
    patch['recurrenceStart'] = null;
    patch['recurrenceEnd'] = null;
    patch['recurrenceCount'] = null;
    return;
  }
  patch['recurrenceType'] = _recurrenceType(raw);
  if (raw.containsKey('interval')) patch['recurrenceInterval'] = raw['interval'];
  if (raw.containsKey('days')) patch['recurrenceDays'] = (raw['days'] as List).join(',');
  if (raw.containsKey('startAt'))
    patch['recurrenceStart'] =
        raw['startAt'] == null ? null : _parseInstant(raw['startAt'] as String, 'recurrence.startAt');
  if (raw.containsKey('endAt'))
    patch['recurrenceEnd'] = raw['endAt'] == null ? null : _parseInstant(raw['endAt'] as String, 'recurrence.endAt');
  if (raw.containsKey('count')) patch['recurrenceCount'] = raw['count'];
}

void _copy<T>(McpToolArguments args, Map<String, Object?> patch, String name, T? Function(String) read) {
  if (args.contains(name)) patch[name] = read(name);
}

Map<String, int> _tagOrder(List<dynamic> raw) {
  final result = <String, int>{};
  for (final entry in raw) {
    if (entry is! Map<String, dynamic> || entry['tagId'] is! String || entry['order'] is! int) {
      throw _validation('tagOrder', 'values must be integers');
    }
    result[entry['tagId'] as String] = entry['order'] as int;
  }
  return Map.unmodifiable(result);
}

McpToolException _validation(String field, String message) => McpToolException(McpToolError(
    code: McpToolErrorCode.validationError, message: 'Argument "$field" $message.', details: {'field': field}));
