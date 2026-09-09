part of 'habit_tools.dart';

const _read = ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false);
const _add = ToolAnnotations(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false);
const _mutate = ToolAnnotations(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false);
const _destroy =
    ToolAnnotations(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false);

JsonObject _schema(Map<String, JsonSchema> properties, [List<String> required = const []]) =>
    JsonSchema.object(properties: properties, required: required, additionalProperties: false);
JsonSchema get _nullableString => JsonSchema.oneOf([JsonSchema.string(), JsonSchema.nullValue()]);
JsonSchema get _nullableInt => JsonSchema.oneOf([JsonSchema.integer(), JsonSchema.nullValue()]);
JsonSchema get _stringsSchema => JsonSchema.array(items: JsonSchema.string(), uniqueItems: true);
JsonSchema get _intsSchema => JsonSchema.array(items: JsonSchema.integer(), uniqueItems: true);
JsonSchema get _id => JsonSchema.string(minLength: 1);
JsonSchema get _dateSchema => JsonSchema.string(pattern: _datePattern);
JsonSchema get _instantSchema => JsonSchema.string(format: 'date-time');
JsonSchema get _revisionSchema => JsonSchema.string(format: 'date-time');
JsonSchema get _typeSchema => JsonSchema.string(enumValues: const ['good', 'bad']);
JsonSchema get _statusSchema => JsonSchema.string(enumValues: const ['complete', 'not_done', 'skipped']);

JsonObject get _idInput => _schema({'id': _id}, ['id']);
JsonObject get _revisionInput => _schema({'id': _id, 'expectedRevision': _revisionSchema}, ['id', 'expectedRevision']);
JsonObject get _rangeInput =>
    _schema({'habitId': _id, 'from': _dateSchema, 'to': _dateSchema}, ['habitId', 'from', 'to']);
JsonObject get _listInput => _schema({
      'cursor': JsonSchema.string(),
      'pageSize': JsonSchema.integer(minimum: 1, maximum: _maximumPageSize),
      'search': JsonSchema.string(),
      'tagIds': _stringsSchema,
      'withoutTags': JsonSchema.boolean(),
      'isArchived': JsonSchema.boolean(),
      'excludeCompleted': JsonSchema.boolean(),
      'forDate': _dateSchema,
      'sort': JsonSchema.string(),
      'groupBy': JsonSchema.string(),
      'customTagOrder': _stringsSchema,
      'includeArchivedTags': JsonSchema.boolean(),
    });
JsonObject get _habitFields => _schema({
      'name': JsonSchema.string(minLength: 1),
      'description': JsonSchema.string(),
      'type': _typeSchema,
      'estimatedMinutes': _nullableInt,
      'hasReminder': JsonSchema.boolean(),
      'reminderTime': _nullableString,
      'reminderDays': _intsSchema,
      'hasGoal': JsonSchema.boolean(),
      'targetFrequency': JsonSchema.integer(minimum: 1),
      'periodDays': JsonSchema.integer(minimum: 1),
      'dailyTarget': _nullableInt,
      'tagIds': _stringsSchema,
      'tagOrder': _stringsSchema,
    });
JsonObject get _createInput => _schema({
      for (final entry in _habitFields.properties!.entries)
        if (entry.key != 'tagOrder') entry.key: entry.value,
    }, [
      'name',
      'type'
    ]);
JsonObject get _updateInput =>
    _schema({'id': _id, 'expectedRevision': _revisionSchema, ..._habitFields.properties!}, ['id', 'expectedRevision']);
JsonObject get _archiveInput => _schema(
    {'id': _id, 'expectedRevision': _revisionSchema, 'isArchived': JsonSchema.boolean()},
    ['id', 'expectedRevision', 'isArchived']);
JsonObject get _reorderInput => _schema({
      'id': _id,
      'expectedRevision': _revisionSchema,
      'targetIndex': JsonSchema.integer(minimum: 0),
      'beforeId': _nullableString,
      'afterId': _nullableString,
    }, [
      'id',
      'expectedRevision',
      'targetIndex'
    ]);
JsonObject get _recordListInput => _schema({
      'habitId': _id,
      'from': _dateSchema,
      'to': _dateSchema,
      'cursor': JsonSchema.string(),
      'pageSize': JsonSchema.integer(minimum: 1, maximum: _maximumPageSize),
    }, [
      'habitId',
      'from',
      'to'
    ]);
JsonObject get _recordSetInput => _schema({
      'habitId': _id,
      'date': _dateSchema,
      'status': _statusSchema,
      'count': JsonSchema.integer(minimum: 0),
    }, [
      'habitId',
      'date',
      'status'
    ]);
JsonObject get _recordUndoInput => _schema({'habitId': _id, 'date': _dateSchema, 'recordId': _id}, ['habitId', 'date']);
JsonObject get _timeListInput => _schema({'habitId': _id, 'from': _instantSchema, 'to': _instantSchema}, ['habitId']);
JsonObject get _timeAddInput => _schema({
      'habitId': _id,
      'durationSeconds': JsonSchema.integer(minimum: 1),
      'occurredAt': _instantSchema,
    }, [
      'habitId',
      'durationSeconds'
    ]);
JsonObject get _timeUpdateInput => _schema({
      'habitId': _id,
      'date': _dateSchema,
      'totalDurationSeconds': JsonSchema.integer(minimum: 0),
      'expectedRevision': _revisionSchema,
    }, [
      'habitId',
      'date',
      'totalDurationSeconds',
      'expectedRevision'
    ]);

JsonSchema get _tagOutput => _schema({
      'id': _id,
      'name': JsonSchema.string(),
      'color': _nullableString,
    }, [
      'id',
      'name',
      'color'
    ]);
JsonSchema get _habitSummaryOutput => _schema({
      'id': _id,
      'name': JsonSchema.string(),
      'type': _typeSchema,
      'estimatedMinutes': _nullableInt,
      'totalDurationSeconds': JsonSchema.integer(),
      'isArchived': JsonSchema.boolean(),
      'dailyState': JsonSchema.string(enumValues: HabitDayState.values.map((value) => value.name).toList()),
      'tags': JsonSchema.array(items: _tagOutput),
    }, [
      'id',
      'name',
      'type',
      'estimatedMinutes',
      'totalDurationSeconds',
      'isArchived',
      'dailyState',
      'tags'
    ]);
JsonSchema get _recordOutput => _schema({
      'id': _id,
      'date': _dateSchema,
      'occurredAt': _instantSchema,
      'status': _statusSchema,
    }, [
      'id',
      'date',
      'occurredAt',
      'status'
    ]);
JsonObject _pageOutput(JsonSchema item) => _schema({
      'items': JsonSchema.array(items: item),
      'totalItemCount': JsonSchema.integer(),
      'nextCursor': _nullableString,
    }, [
      'items',
      'totalItemCount',
      'nextCursor'
    ]);
JsonObject get _habitListOutput => _pageOutput(_habitSummaryOutput);
JsonObject get _recordListOutput => _pageOutput(_recordOutput);
JsonObject get _habitReadOutput => _schema({
      'id': _id,
      'name': JsonSchema.string(),
      'description': JsonSchema.string(),
      'type': _typeSchema,
      'estimatedMinutes': _nullableInt,
      'hasReminder': JsonSchema.boolean(),
      'reminderTime': _nullableString,
      'reminderDays': _intsSchema,
      'hasGoal': JsonSchema.boolean(),
      'targetFrequency': JsonSchema.integer(),
      'periodDays': JsonSchema.integer(),
      'dailyTarget': _nullableInt,
      'isArchived': JsonSchema.boolean(),
      'archivedAt': _nullableString,
      'createdAt': _instantSchema,
      'order': JsonSchema.string(),
      'revision': _revisionSchema,
    }, [
      'id',
      'name',
      'description',
      'type',
      'estimatedMinutes',
      'hasReminder',
      'reminderTime',
      'reminderDays',
      'hasGoal',
      'targetFrequency',
      'periodDays',
      'dailyTarget',
      'isArchived',
      'archivedAt',
      'createdAt',
      'order',
      'revision'
    ]);
JsonObject get _revisionOutput => _schema({'id': _id, 'revision': _revisionSchema}, ['id', 'revision']);
JsonObject get _idOnlyOutput => _schema({'id': _id}, ['id']);
JsonObject get _archiveOutput => _schema(
    {'id': _id, 'isArchived': JsonSchema.boolean(), 'revision': _revisionSchema}, ['id', 'isArchived', 'revision']);
JsonObject get _deleteOutput => _schema({'id': _id, 'deletedAt': _instantSchema}, ['id', 'deletedAt']);
JsonObject get _orderOutput =>
    _schema({'id': _id, 'order': JsonSchema.string(), 'revision': _revisionSchema}, ['id', 'order', 'revision']);
JsonObject get _recordSetOutput => _schema(
    {'habitId': _id, 'date': _dateSchema, 'status': _statusSchema, 'count': JsonSchema.integer()},
    ['habitId', 'date', 'status', 'count']);
JsonObject get _undoOutput => _schema({'habitId': _id, 'date': _dateSchema, 'remainingCount': JsonSchema.integer()},
    ['habitId', 'date', 'remainingCount']);
JsonObject get _dailyOutput => _schema({
      'days': JsonSchema.array(
          items: _schema({
        'date': _dateSchema,
        'status': JsonSchema.string(enumValues: HabitDayState.values.map((value) => value.name).toList()),
        'count': JsonSchema.integer(),
        'target': JsonSchema.integer(),
      }, [
        'date',
        'status',
        'count',
        'target'
      ])),
      'summary': _schema({for (final state in HabitDayState.values) state.name: JsonSchema.integer()}),
    }, [
      'days',
      'summary'
    ]);
JsonObject get _statisticsOutput => _schema({
      'overallScore': JsonSchema.number(),
      'monthlyScore': JsonSchema.number(),
      'yearlyScore': JsonSchema.number(),
      'totalRecords': JsonSchema.integer(),
      'monthlyScores': JsonSchema.array(
          items: _schema({
        'month': _dateSchema,
        'score': JsonSchema.number(),
      }, [
        'month',
        'score'
      ])),
      'topStreaks': JsonSchema.array(
          items: _schema({
        'startDate': _dateSchema,
        'endDate': _dateSchema,
        'days': JsonSchema.integer(),
        'completions': _nullableInt,
      }, [
        'startDate',
        'endDate',
        'days',
        'completions'
      ])),
      'yearlyFrequency': JsonSchema.array(
          items: _schema({
        'dayOfYear': JsonSchema.integer(),
        'count': JsonSchema.integer(),
      }, [
        'dayOfYear',
        'count'
      ])),
      'goalSuccessRate': JsonSchema.oneOf([JsonSchema.number(), JsonSchema.nullValue()]),
      'daysGoalMet': _nullableInt,
      'totalDaysWithGoal': _nullableInt,
    }, [
      'overallScore',
      'monthlyScore',
      'yearlyScore',
      'totalRecords',
      'monthlyScores',
      'topStreaks',
      'yearlyFrequency',
      'goalSuccessRate',
      'daysGoalMet',
      'totalDaysWithGoal'
    ]);
JsonObject get _timeListOutput => _schema({
      'items': JsonSchema.array(
          items: _schema({
        'id': _id,
        'occurredAt': _instantSchema,
        'durationSeconds': JsonSchema.integer(),
        'revision': _revisionSchema,
      }, [
        'id',
        'occurredAt',
        'durationSeconds',
        'revision'
      ])),
      'totalDurationSeconds': JsonSchema.integer()
    }, [
      'items',
      'totalDurationSeconds'
    ]);
JsonObject get _totalOutput => _schema({'totalDurationSeconds': JsonSchema.integer()}, ['totalDurationSeconds']);
