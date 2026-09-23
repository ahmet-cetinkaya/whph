part of 'sync_tools.dart';

final _emptyInput = JsonSchema.object(additionalProperties: false);
final _idInput = _object({'id': JsonSchema.string(minLength: 1)}, const ['id']);
final _listInput = _object({
  'cursor': JsonSchema.string(),
  'pageSize': JsonSchema.integer(minimum: 1, maximum: 200)
});
final _updateInput = _object({
  'id': JsonSchema.string(minLength: 1),
  'expectedRevision': JsonSchema.string(format: 'date-time'),
  'name': JsonSchema.string(minLength: 1, maxLength: 200),
  'fromIp': JsonSchema.string(),
  'toIp': JsonSchema.string(),
}, const [
  'id',
  'expectedRevision'
]);
final _deleteInput = _object({
  'id': JsonSchema.string(minLength: 1),
  'expectedRevision': JsonSchema.string(format: 'date-time'),
}, const [
  'id',
  'expectedRevision'
]);
final _pairInput = _object({
  'peer': _object({
    'deviceId': JsonSchema.string(minLength: 1, maxLength: 200),
    'name': JsonSchema.string(minLength: 1, maxLength: 200),
    'ipAddress': JsonSchema.string(),
    'port': JsonSchema.integer(minimum: 1, maximum: 65535),
  }, const [
    'deviceId',
    'name',
    'ipAddress',
    'port'
  ]),
}, const [
  'peer'
]);
final _statusOutput = _object({
  'state': JsonSchema.string(),
  'currentDeviceId': JsonSchema.string(),
  'lastSyncTime': JsonSchema.string(),
  'isManual': JsonSchema.boolean(),
  'error': JsonSchema.string(),
}, const [
  'state',
  'isManual'
]);
final _deviceOutput = _object({
  'id': JsonSchema.string(),
  'name': JsonSchema.string(),
  'fromIp': JsonSchema.string(),
  'toIp': JsonSchema.string(),
  'fromDeviceId': JsonSchema.string(),
  'toDeviceId': JsonSchema.string(),
  'lastSyncDate': JsonSchema.string(),
  'revision': JsonSchema.string(),
  'syncState': JsonSchema.string(),
}, const [
  'id',
  'fromIp',
  'toIp',
  'fromDeviceId',
  'toDeviceId',
  'revision',
  'syncState'
]);
final _deviceMutationOutput = _object({
  'id': JsonSchema.string(),
  'name': JsonSchema.string(),
  'fromIp': JsonSchema.string(),
  'toIp': JsonSchema.string(),
  'fromDeviceId': JsonSchema.string(),
  'toDeviceId': JsonSchema.string(),
  'lastSyncDate': JsonSchema.string(),
  'revision': JsonSchema.string(),
  'syncState': JsonSchema.string(),
  'committed': JsonSchema.boolean(),
  'syncStatus': JsonSchema.string(enumValues: const ['succeeded', 'failed']),
}, const [
  'id',
  'fromIp',
  'toIp',
  'fromDeviceId',
  'toDeviceId',
  'revision',
  'syncState',
  'committed',
  'syncStatus'
]);
final _pageOutput = _object({
  'items': JsonSchema.array(items: _deviceOutput),
  'total': JsonSchema.integer(),
  'nextCursor': JsonSchema.string(),
}, const [
  'items',
  'total'
]);
final _deleteOutput = _object({
  'id': JsonSchema.string(),
  'deletedAt': JsonSchema.string(),
  'committed': JsonSchema.boolean(),
  'syncStatus': JsonSchema.string(enumValues: const ['succeeded', 'failed']),
}, const [
  'id',
  'deletedAt',
  'committed',
  'syncStatus'
]);
final _operationOutput = _object({
  'operationId': JsonSchema.string(),
  'status': JsonSchema.string(),
  'requiresApproval': JsonSchema.boolean(),
  'expiresAt': JsonSchema.string(),
  'peerSummary': JsonSchema.string(),
}, const [
  'operationId',
  'status',
  'requiresApproval',
  'expiresAt',
  'peerSummary'
]);

JsonObject _object(Map<String, JsonSchema> properties,
        [List<String>? required]) =>
    JsonSchema.object(
        properties: properties,
        required: required,
        additionalProperties: false);

const _read = ToolAnnotations(
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false);
const _mutation = ToolAnnotations(
    readOnlyHint: false,
    destructiveHint: true,
    idempotentHint: true,
    openWorldHint: false);
const _delete = ToolAnnotations(
    readOnlyHint: false,
    destructiveHint: true,
    idempotentHint: false,
    openWorldHint: false);
const _additive = ToolAnnotations(
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false);
