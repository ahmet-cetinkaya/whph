part of 'task_tools.dart';

const _read = ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false);
const _additive =
    ToolAnnotations(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false);
const _mutation =
    ToolAnnotations(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false);
const _destructive =
    ToolAnnotations(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false);

JsonSchema get _nullableString => JsonSchema.anyOf([JsonSchema.string(), JsonSchema.nullValue()]);
JsonSchema get _nullableInt => JsonSchema.anyOf([JsonSchema.integer(), JsonSchema.nullValue()]);
JsonSchema get _instant => JsonSchema.string(format: 'date-time');
JsonSchema get _nullableInstantSchema => JsonSchema.anyOf([_instant, JsonSchema.nullValue()]);
JsonSchema get _strings => JsonSchema.array(items: JsonSchema.string(), uniqueItems: true);
JsonObject _closed(Map<String, JsonSchema> properties, [List<String>? required]) =>
    JsonSchema.object(properties: properties, required: required, additionalProperties: false);

final _reminderSchema = _closed({
  'time': JsonSchema.string(enumValues: ReminderTime.values.map((value) => value.name).toList()),
  'customOffsetMinutes': JsonSchema.integer(minimum: 0),
}, [
  'time'
]);
final _recurrenceSchema = _closed({
  'type': JsonSchema.string(enumValues: RecurrenceType.values.map((value) => value.name).toList()),
  'interval': JsonSchema.integer(minimum: 1),
  'days': _strings,
  'startAt': _nullableInstantSchema,
  'endAt': _nullableInstantSchema,
  'count': _nullableInt,
}, [
  'type'
]);
final _sortSchema = _closed({
  'field': JsonSchema.string(enumValues: TaskSortFields.values.map((value) => value.name).toList()),
  'direction': JsonSchema.string(enumValues: ['asc', 'desc']),
}, [
  'field',
  'direction'
]);
final _tagSchema = _closed({
  'id': JsonSchema.string(),
  'name': JsonSchema.string(),
  'color': _nullableString,
  'type': JsonSchema.string(),
  'order': JsonSchema.integer(),
});
final _summarySchema = _closed({
  'id': JsonSchema.string(),
  'title': JsonSchema.string(),
  'priority': _nullableString,
  'plannedAt': _nullableInstantSchema,
  'deadlineAt': _nullableInstantSchema,
  'completedAt': _nullableInstantSchema,
  'isCompleted': JsonSchema.boolean(),
  'statusId': _nullableString,
  'parentId': _nullableString,
  'estimatedMinutes': _nullableInt,
  'totalDurationSeconds': JsonSchema.integer(),
  'order': JsonSchema.string(),
  'tags': JsonSchema.array(items: _tagSchema),
  'revision': _instant,
});
final _listInput = _closed({
  'cursor': JsonSchema.string(pattern: r'^\d+$'),
  'pageSize': JsonSchema.integer(minimum: 1, maximum: 200),
  'search': JsonSchema.string(),
  'plannedFrom': _instant,
  'plannedTo': _instant,
  'deadlineFrom': _instant,
  'deadlineTo': _instant,
  'completedFrom': _instant,
  'completedTo': _instant,
  'dateFilterMode': JsonSchema.string(enumValues: ['and', 'or']),
  'includeUnscheduled': JsonSchema.boolean(),
  'tagIds': _strings,
  'withoutTags': JsonSchema.boolean(),
  'isCompleted': JsonSchema.boolean(),
  'parentId': JsonSchema.string(),
  'includeDescendants': JsonSchema.boolean(),
  'sort': JsonSchema.array(items: _sortSchema),
  'groupBy': _sortSchema,
  'customTagOrder': _strings,
  'includeArchivedTags': JsonSchema.boolean(),
});
final _idInput = _closed({'id': JsonSchema.string(minLength: 1)}, ['id']);
final _revisionInput =
    _closed({'id': JsonSchema.string(minLength: 1), 'expectedRevision': _instant}, ['id', 'expectedRevision']);
final _createFields = <String, JsonSchema>{
  'title': JsonSchema.string(minLength: 1),
  'description': JsonSchema.string(),
  'priority': JsonSchema.string(enumValues: EisenhowerPriority.values.map((value) => value.name).toList()),
  'plannedAt': _instant,
  'deadlineAt': _instant,
  'estimatedMinutes': JsonSchema.integer(minimum: 0),
  'statusId': JsonSchema.string(),
  'parentId': JsonSchema.string(),
  'tagIds': _strings,
  'plannedReminder': _reminderSchema,
  'deadlineReminder': _reminderSchema,
  'recurrence': _recurrenceSchema,
};
final _createInput = _closed(_createFields, ['title']);
final _updateInput = _closed({
  'id': JsonSchema.string(),
  'expectedRevision': _instant,
  ..._createFields.map((key, value) => MapEntry(
      key,
      [
        'description',
        'plannedAt',
        'deadlineAt',
        'estimatedMinutes',
        'statusId',
        'parentId',
        'plannedReminder',
        'deadlineReminder',
        'recurrence'
      ].contains(key)
          ? JsonSchema.anyOf([value, JsonSchema.nullValue()])
          : value)),
  'tagOrder': JsonSchema.array(
      items: _closed({
        'tagId': JsonSchema.string(),
        'order': JsonSchema.integer(minimum: 0),
      }, [
        'tagId',
        'order'
      ]),
      uniqueItems: true),
}, [
  'id',
  'expectedRevision'
]);
final _completionInput = _closed({
  'id': JsonSchema.string(),
  'expectedRevision': _instant,
  'isCompleted': JsonSchema.boolean(),
  'completedAt': _instant
}, [
  'id',
  'expectedRevision',
  'isCompleted'
]);
final _reorderInput = _closed({
  'id': JsonSchema.string(),
  'expectedRevision': _instant,
  'targetIndex': JsonSchema.integer(minimum: 0),
  'beforeId': JsonSchema.string(),
  'afterId': JsonSchema.string()
}, [
  'id',
  'expectedRevision',
  'targetIndex'
]);
final _importInput = _closed({
  'format': JsonSchema.string(enumValues: ['csv']),
  'csv': JsonSchema.string(),
  'importType': JsonSchema.string(enumValues: TaskImportType.values.map((value) => value.name).toList())
}, [
  'format',
  'csv',
  'importType'
]);
final _timeListInput = _closed({'taskId': JsonSchema.string(), 'from': _instant, 'to': _instant}, ['taskId']);
final _timeAddInput = _closed(
    {'taskId': JsonSchema.string(), 'durationSeconds': JsonSchema.integer(minimum: 1), 'occurredAt': _instant},
    ['taskId', 'durationSeconds']);
final _timeUpdateInput = _closed({
  'taskId': JsonSchema.string(),
  'date': JsonSchema.string(format: 'date'),
  'totalDurationSeconds': JsonSchema.integer(minimum: 0),
  'expectedRevision': _instant
}, [
  'taskId',
  'date',
  'totalDurationSeconds',
  'expectedRevision'
]);
final _timeTotalInput = _closed({'taskId': JsonSchema.string(), 'from': _instant, 'to': _instant}, ['taskId']);
final _idOutput = _closed({'id': JsonSchema.string()}, ['id']);
final _idRevisionOutput = _closed({'id': JsonSchema.string(), 'revision': _instant}, ['id', 'revision']);
final _deleteOutput = _closed({'id': JsonSchema.string(), 'deletedAt': _instant}, ['id', 'deletedAt']);
final _reorderOutput = _closed(
    {'id': JsonSchema.string(), 'order': JsonSchema.string(), 'revision': _instant}, ['id', 'order', 'revision']);
final _completionOutput = _closed({
  'id': JsonSchema.string(),
  'isCompleted': JsonSchema.boolean(),
  'revision': _instant,
  'recurrenceTaskId': JsonSchema.string()
}, [
  'id',
  'isCompleted',
  'revision'
]);
final _pagedOutput = _closed({
  'items': JsonSchema.array(items: _summarySchema),
  'totalCount': JsonSchema.integer(),
  'nextCursor': _nullableString
}, [
  'items',
  'totalCount',
  'nextCursor'
]);
final _taskOutput = _closed({
  ..._summarySchema.properties ?? {},
  'description': _nullableString,
  'plannedReminder': _reminderSchema,
  'deadlineReminder': _reminderSchema,
  'recurrence': _recurrenceSchema,
  'timeRecords': JsonSchema.array(items: _timeRecordSchema)
});
final _importOutput = _closed(
    {'successCount': JsonSchema.integer(), 'failureCount': JsonSchema.integer(), 'errors': _strings},
    ['successCount', 'failureCount', 'errors']);
final _timeRecordSchema =
    _closed({'id': JsonSchema.string(), 'occurredAt': _instant, 'durationSeconds': JsonSchema.integer()});
final _timeListOutput = _closed(
    {'items': JsonSchema.array(items: _timeRecordSchema), 'totalDurationSeconds': JsonSchema.integer()},
    ['items', 'totalDurationSeconds']);
final _timeTotalOutput = _closed({'totalDurationSeconds': JsonSchema.integer()}, ['totalDurationSeconds']);
