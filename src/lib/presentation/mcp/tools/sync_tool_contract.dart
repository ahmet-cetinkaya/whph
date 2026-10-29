part of 'sync_tools.dart';

final _emptyInput = JsonSchema.object(additionalProperties: false);
final _idInput = _object({'id': JsonSchema.string(minLength: 1)}, const ['id']);
final _listInput = _object({'cursor': JsonSchema.string(), 'pageSize': JsonSchema.integer(minimum: 1, maximum: 200)});
final _updateInput = _object(
  {
    'id': JsonSchema.string(minLength: 1),
    'expectedRevision': JsonSchema.string(minLength: 1),
    'name': JsonSchema.string(minLength: 1, maxLength: 200),
    'addresses': JsonSchema.array(items: JsonSchema.string(), maxItems: 8),
  },
  const ['id', 'expectedRevision'],
);
final _deleteInput = _object(
  {'id': JsonSchema.string(minLength: 1), 'expectedRevision': JsonSchema.string(minLength: 1)},
  const ['id', 'expectedRevision'],
);
final _pairInput = _object(
  {
    'peer': _object(
      {'ipAddress': JsonSchema.string(), 'port': JsonSchema.integer(minimum: 1, maximum: 65535)},
      const ['ipAddress'],
    ),
  },
  const ['peer'],
);
final _runningOutput = _object({'running': JsonSchema.boolean()}, const ['running']);
final _memberFields = <String, JsonSchema>{
  'id': JsonSchema.string(),
  'name': JsonSchema.string(),
  'platform': JsonSchema.string(),
  'addresses': JsonSchema.array(items: JsonSchema.string()),
  'status': JsonSchema.string(),
  'itemsCannotBeApplied': JsonSchema.boolean(),
  'needsRepairing': JsonSchema.boolean(),
  'isThisDevice': JsonSchema.boolean(),
  'lastSuccessfulSync': JsonSchema.string(),
  'revision': JsonSchema.string(),
};
const _memberRequired = [
  'id',
  'name',
  'addresses',
  'status',
  'itemsCannotBeApplied',
  'needsRepairing',
  'isThisDevice',
  'revision',
];
final _memberOutput = _object(_memberFields, _memberRequired);
final _memberMutationOutput = _object(
  {..._memberFields, 'committed': JsonSchema.boolean()},
  [..._memberRequired, 'committed'],
);
final _pageOutput = _object(
  {'items': JsonSchema.array(items: _memberOutput), 'total': JsonSchema.integer(), 'nextCursor': JsonSchema.string()},
  const ['items', 'total'],
);
final _deleteOutput = _object(
  {'id': JsonSchema.string(), 'committed': JsonSchema.boolean()},
  const ['id', 'committed'],
);
final _operationOutput = _object(
  {
    'operationId': JsonSchema.string(),
    'status': JsonSchema.string(),
    'requiresApproval': JsonSchema.boolean(),
    'expiresAt': JsonSchema.string(),
    'peerSummary': JsonSchema.string(),
    'requiresUserConfirmation': JsonSchema.boolean(),
  },
  const ['operationId', 'status', 'requiresApproval', 'expiresAt', 'peerSummary', 'requiresUserConfirmation'],
);

JsonObject _object(Map<String, JsonSchema> properties, [List<String>? required]) =>
    JsonSchema.object(properties: properties, required: required, additionalProperties: false);

const _read = ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false);
const _mutation = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: true,
  openWorldHint: false,
);
const _delete = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: false,
  openWorldHint: false,
);
const _additive = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: false,
  openWorldHint: false,
);
