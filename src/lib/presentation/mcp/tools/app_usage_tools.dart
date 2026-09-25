import 'package:acore/acore.dart' show BusinessException, SortDirection;
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_distinct_device_names_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_ignore_rules_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_mcp_actions.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

const _defaultPageSize = 50;
const _maximumPageSize = 200;
const _maximumRangeDays = 366;

List<McpToolDefinition> buildAppUsageTools({
  required Mediator mediator,
  required AppUsageActions actions,
  required McpUsageCommitGuard authorizeBeforeCommit,
}) =>
    [
      _tool('whph_usage_list', 'Lists bounded application usage summaries.', _listInputSchema(), _pagedSchema(),
          {McpScopes.usageRead, McpScopes.tagsRead}, (arguments, _) async {
        final page = _page(arguments);
        final range = _optionalBounds(arguments, 'from', 'to');
        final comparison = _optionalRange(arguments, 'compareFrom', 'compareTo');
        final response = await mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(
          GetListByTopAppUsagesQuery(
            pageIndex: page.index,
            pageSize: page.size,
            filterByTags: _strings(arguments, 'tagIds'),
            showNoTagsFilter: arguments.optionalBool('withoutTags') ?? false,
            startDate: range.start,
            endDate: range.end,
            compareStartDate: comparison?.start,
            compareEndDate: comparison?.end,
            searchByProcessName: arguments.optionalString('search'),
            filterByDevices: _strings(arguments, 'deviceNames'),
            sortBy: _sort(arguments.optionalList('sort')),
            groupBy: _group(arguments.optionalObject('groupBy')),
            enableGrouping: arguments.contains('groupBy'),
            sortByCustomOrder: arguments.contains('customTagOrder'),
            customTagSortOrder: _strings(arguments, 'customTagOrder'),
          ),
        );
        return _paged(
          response.items.map((item) => {
                'id': item.id,
                'name': item.name,
                'displayName': item.displayName,
                'color': item.color,
                'deviceName': item.deviceName,
                'durationSeconds': item.duration,
                'compareDurationSeconds': item.compareDuration,
                'tags': item.tags.map(_tagJson).toList(growable: false),
              }),
          page,
          response.totalItemCount,
        );
      }),
      _tool(
          'whph_usage_read',
          'Reads one application usage and its tags.',
          _idSchema(),
          _objectSchema([
            'id',
            'name',
            'displayName',
            'color',
            'deviceName',
            'tags',
            'timeRecords',
            'hasMoreTimeRecords',
            'revision',
          ]),
          {McpScopes.usageRead, McpScopes.tagsRead}, (arguments, _) async {
        final id = arguments.requireString('id');
        late final GetAppUsageQueryResponse usage;
        try {
          usage = await mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(GetAppUsageQuery(id: id));
        } on BusinessException {
          throw AppUsageNotFound(id);
        }
        final tags = await mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(
          GetListAppUsageTagsQuery(appUsageId: id, pageIndex: 0, pageSize: _maximumPageSize),
        );
        return {
          'id': id,
          'name': usage.name,
          'displayName': usage.displayName,
          'color': usage.color,
          'deviceName': usage.deviceName,
          'tags': tags.items.map(_tagJson).toList(growable: false),
          'timeRecords': usage.timeRecords
              .map((record) => {
                    'id': record.id,
                    'occurredAt': record.occurredAt.toIso8601String(),
                    'durationSeconds': record.durationSeconds,
                  })
              .toList(growable: false),
          'hasMoreTimeRecords': usage.hasMoreTimeRecords,
          'revision': _revision(usage.createdDate, usage.modifiedDate),
        };
      }),
      _tool(
          'whph_usage_update',
          'Updates usage metadata and tag associations with revision protection.',
          _usageUpdateSchema(),
          _mutationSchema(),
          {McpScopes.usageWrite, McpScopes.tagsWrite}, (arguments, authorizeCommit) async {
        final result = await actions.update(
          id: arguments.requireString('id'),
          expectedRevision: _instant(arguments, 'expectedRevision'),
          displayName: _optionalUpdate(arguments, 'displayName'),
          color: _optionalUpdate(arguments, 'color'),
          tagIds: _strings(arguments, 'tagIds'),
          tagOrder: _strings(arguments, 'tagOrder'),
          authorizeCommit: authorizeCommit,
        );
        return {'id': result.id, 'revision': result.revision.toIso8601String()};
      }, readOnly: false, destructive: true, authorizeBeforeCommit: authorizeBeforeCommit),
      _tool('whph_usage_delete', 'Deletes usage and related records with revision protection.', _revisionSchema(),
          _deleteSchema(), {McpScopes.usageDelete}, (arguments, authorizeCommit) async {
        final result = await actions.delete(
          arguments.requireString('id'),
          _instant(arguments, 'expectedRevision'),
          authorizeCommit: authorizeCommit,
        );
        return {'id': result.id, 'deletedAt': result.deletedAt.toIso8601String()};
      }, readOnly: false, idempotent: false, destructive: true, authorizeBeforeCommit: authorizeBeforeCommit),
      _tool(
          'whph_usage_statistics',
          'Returns bounded daily and hourly application usage statistics.',
          _statisticsSchema(),
          _objectSchema(['daily', 'hourly', 'totalDurationSeconds', 'compareTotalDurationSeconds']),
          {McpScopes.usageRead}, (arguments, _) async {
        final range = _requiredRange(arguments, 'from', 'to');
        final comparison = _optionalRange(arguments, 'compareFrom', 'compareTo');
        final result = await mediator.send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(
          GetAppUsageStatisticsQuery(
            appUsageId: arguments.requireString('id'),
            startDate: range.start,
            endDate: range.end,
            compareStartDate: comparison?.start,
            compareEndDate: comparison?.end,
          ),
        );
        return {
          'daily': result.dailyUsage
              .map((day) => {
                    'dayOfWeek': day.dayOfWeek,
                    'durationSeconds': day.totalDuration,
                    'compareDurationSeconds': day.compareDuration,
                  })
              .toList(growable: false),
          'hourly': result.hourlyUsage
              .map((hour) => {
                    'hour': hour.hour,
                    'durationSeconds': hour.totalDuration,
                    'compareDurationSeconds': hour.compareDuration,
                  })
              .toList(growable: false),
          'totalDurationSeconds': result.totalDuration,
          'compareTotalDurationSeconds': result.compareTotalDuration,
        };
      }),
      _tool('whph_usage_devices_list', 'Lists device names represented in usage records.', _emptySchema(),
          _objectSchema(['deviceNames']), {McpScopes.usageRead}, (arguments, _) async {
        final result = await mediator.send<GetDistinctDeviceNamesQuery, GetDistinctDeviceNamesQueryResponse>(
          GetDistinctDeviceNamesQuery(),
        );
        return {
          'deviceNames': List<String>.unmodifiable(
            List<String>.of(result.deviceNames)..sort(),
          )
        };
      }),
      _tool('whph_usage_tracking_start', 'Starts native usage tracking when supported and already permitted.',
          _emptySchema(), _objectSchema(['state']), {McpScopes.usageTrack}, (arguments, authorizeCommit) async {
        final state = await actions.startTracking(authorizeCommit: authorizeCommit);
        if (state == 'permission_required') {
          throw McpToolException(McpToolError(
            code: McpToolErrorCode.permissionRequired,
            message: 'Usage access must be granted in the operating system settings.',
          ));
        }
        if (state == 'unsupported_platform') {
          throw McpToolException(McpToolError(
            code: McpToolErrorCode.unsupportedPlatform,
            message: 'Application usage tracking is unavailable on this platform.',
          ));
        }
        return {'state': state};
      }, readOnly: false, destructive: true, authorizeBeforeCommit: authorizeBeforeCommit),
      _tool('whph_usage_tracking_stop', 'Stops and flushes native usage tracking.', _emptySchema(),
          _objectSchema(['state']), {McpScopes.usageTrack}, (arguments, authorizeCommit) async {
        final state = await actions.stopTracking(authorizeCommit: authorizeCommit);
        if (state == 'unsupported_platform') {
          throw McpToolException(McpToolError(
            code: McpToolErrorCode.unsupportedPlatform,
            message: 'Application usage tracking is unavailable on this platform.',
          ));
        }
        return {'state': state};
      }, readOnly: false, destructive: true, authorizeBeforeCommit: authorizeBeforeCommit),
      _tool('whph_usage_tag_rules_list', 'Lists bounded automatic usage tag rules.', _ruleListSchema(true),
          _pagedSchema(), {McpScopes.usageRead}, (arguments, _) async {
        final page = _page(arguments);
        final result = await mediator.send<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse>(
          GetListAppUsageTagRulesQuery(
            pageIndex: page.index,
            pageSize: page.size,
            filterByTags: _strings(arguments, 'tagIds'),
          ),
        );
        return _paged(
          result.items.map((rule) => {
                'id': rule.id,
                'pattern': rule.pattern,
                'tag': {'id': rule.tagId, 'name': rule.tagName, 'color': rule.tagColor},
                'description': rule.description,
                'revision': _revision(rule.createdDate, null),
              }),
          page,
          result.totalItemCount,
        );
      }),
      _tool('whph_usage_tag_rules_create', 'Creates a validated automatic usage tag rule.', _ruleCreateSchema(true),
          _mutationSchema(), {McpScopes.usageWrite, McpScopes.tagsWrite}, (arguments, authorizeCommit) async {
        final result = await actions.createTagRule(
          arguments.requireString('pattern'),
          arguments.requireString('tagId'),
          arguments.optionalString('description'),
          authorizeCommit: authorizeCommit,
        );
        return {'id': result.id, 'revision': result.revision.toIso8601String()};
      }, readOnly: false, idempotent: false, authorizeBeforeCommit: authorizeBeforeCommit),
      _ruleDeleteTool('whph_usage_tag_rules_delete', actions.deleteTagRule, authorizeBeforeCommit),
      _tool('whph_usage_ignore_rules_list', 'Lists bounded application usage ignore rules.', _ruleListSchema(false),
          _pagedSchema(), {McpScopes.usageRead}, (arguments, _) async {
        final page = _page(arguments);
        final result = await mediator.send<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse>(
          GetListAppUsageIgnoreRulesQuery(pageIndex: page.index, pageSize: page.size),
        );
        return _paged(
          result.items.map((rule) => {
                'id': rule.id,
                'pattern': rule.pattern,
                'description': rule.description,
                'revision': _revision(rule.createdDate, null),
              }),
          page,
          result.totalItemCount,
        );
      }),
      _tool('whph_usage_ignore_rules_create', 'Creates a validated usage ignore rule.', _ruleCreateSchema(false),
          _mutationSchema(), {McpScopes.usageWrite}, (arguments, authorizeCommit) async {
        final result = await actions.createIgnoreRule(
          arguments.requireString('pattern'),
          arguments.optionalString('description'),
          authorizeCommit: authorizeCommit,
        );
        return {'id': result.id, 'revision': result.revision.toIso8601String()};
      }, readOnly: false, idempotent: false, authorizeBeforeCommit: authorizeBeforeCommit),
      _ruleDeleteTool('whph_usage_ignore_rules_delete', actions.deleteIgnoreRule, authorizeBeforeCommit),
    ];

typedef _Handler = Future<Map<String, dynamic>> Function(
  McpToolArguments arguments,
  ApplicationMutationGuard authorizeCommit,
);
typedef _DeleteRule = Future<AppUsageDeleteResult> Function(
  String id,
  DateTime revision, {
  ApplicationMutationGuard? authorizeCommit,
});
typedef McpUsageCommitGuard = Future<bool> Function(RequestHandlerExtra extra, Set<String> scopes);

McpToolDefinition _tool(
  String name,
  String description,
  JsonObject inputSchema,
  JsonObject outputSchema,
  Set<String> scopes,
  _Handler handler, {
  bool readOnly = true,
  bool destructive = false,
  bool idempotent = true,
  McpUsageCommitGuard? authorizeBeforeCommit,
}) =>
    McpToolDefinition(
      name: name,
      description: description,
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      annotations: ToolAnnotations(
        readOnlyHint: readOnly,
        destructiveHint: destructive,
        idempotentHint: idempotent,
        openWorldHint: false,
      ),
      requiredScopes: scopes,
      handler: (arguments, extra) async {
        try {
          if (authorizeBeforeCommit != null && !await authorizeBeforeCommit(extra, scopes)) {
            return McpToolResult.failure(McpToolError(
              code: McpToolErrorCode.permissionDenied,
              message: 'Permission was revoked before the change could commit.',
            ));
          }
          return McpToolResult.success(await handler(
            arguments,
            () async => authorizeBeforeCommit == null || await authorizeBeforeCommit(extra, scopes),
          ));
        } on AppUsageNotFound catch (_) {
          return McpToolResult.failure(
              McpToolError(code: McpToolErrorCode.notFound, message: 'The record was not found.'));
        } on AppUsageRevisionConflict catch (_) {
          return McpToolResult.failure(
              McpToolError(code: McpToolErrorCode.conflict, message: 'The record changed since it was read.'));
        } on MutationAuthorizationException {
          return McpToolResult.failure(McpToolError(
            code: McpToolErrorCode.permissionDenied,
            message: 'Authorization changed before commit.',
          ));
        } on FormatException catch (error) {
          return McpToolResult.failure(McpToolError(code: McpToolErrorCode.validationError, message: error.message));
        } on ArgumentError catch (error) {
          return McpToolResult.failure(
              McpToolError(code: McpToolErrorCode.validationError, message: '${error.message}'));
        }
      },
    );

McpToolDefinition _ruleDeleteTool(
  String name,
  _DeleteRule delete,
  McpUsageCommitGuard authorizeBeforeCommit,
) =>
    _tool(
      name,
      'Deletes a usage rule with revision protection.',
      _revisionSchema(),
      _deleteSchema(),
      {McpScopes.usageDelete},
      (arguments, commitGuard) async {
        final result = await delete(
          arguments.requireString('id'),
          _instant(arguments, 'expectedRevision'),
          authorizeCommit: commitGuard,
        );
        return {'id': result.id, 'deletedAt': result.deletedAt.toIso8601String()};
      },
      readOnly: false,
      destructive: true,
      idempotent: false,
      authorizeBeforeCommit: authorizeBeforeCommit,
    );

JsonObject _emptySchema() => JsonSchema.object(additionalProperties: false);
JsonObject _objectSchema(List<String> fields) => JsonSchema.object(
      properties: {for (final field in fields) field: JsonSchema.fromJson(const {})},
      additionalProperties: false,
    );
JsonObject _idSchema() => JsonSchema.object(
      properties: {'id': JsonSchema.string()},
      required: ['id'],
      additionalProperties: false,
    );
JsonObject _revisionSchema() => JsonSchema.object(
      properties: {'id': JsonSchema.string(), 'expectedRevision': JsonSchema.string(format: 'date-time')},
      required: ['id', 'expectedRevision'],
      additionalProperties: false,
    );
JsonObject _usageUpdateSchema() => JsonSchema.object(
      properties: {
        'id': JsonSchema.string(),
        'expectedRevision': JsonSchema.string(format: 'date-time'),
        'displayName': JsonSchema.fromJson(const {
          'type': ['string', 'null']
        }),
        'color': JsonSchema.fromJson(const {
          'type': ['string', 'null']
        }),
        'tagIds': JsonSchema.array(items: JsonSchema.string(), maxItems: _maximumPageSize),
        'tagOrder': JsonSchema.array(items: JsonSchema.string(), maxItems: _maximumPageSize),
      },
      required: ['id', 'expectedRevision'],
      additionalProperties: false,
    );
JsonObject _statisticsSchema() => JsonSchema.object(
      properties: {
        'id': JsonSchema.string(),
        'from': JsonSchema.string(format: 'date'),
        'to': JsonSchema.string(format: 'date'),
        'compareFrom': JsonSchema.string(format: 'date'),
        'compareTo': JsonSchema.string(format: 'date'),
      },
      required: ['id', 'from', 'to'],
      additionalProperties: false,
    );
JsonObject _listInputSchema() => JsonSchema.object(
      properties: {
        'cursor': JsonSchema.string(),
        'pageSize': JsonSchema.integer(minimum: 1, maximum: _maximumPageSize),
        'search': JsonSchema.string(),
        'tagIds': JsonSchema.array(items: JsonSchema.string()),
        'withoutTags': JsonSchema.boolean(),
        'deviceNames': JsonSchema.array(items: JsonSchema.string()),
        'from': JsonSchema.string(format: 'date'),
        'to': JsonSchema.string(format: 'date'),
        'compareFrom': JsonSchema.string(format: 'date'),
        'compareTo': JsonSchema.string(format: 'date'),
        'sort': JsonSchema.array(items: _sortSchema()),
        'groupBy': _sortSchema(),
        'customTagOrder': JsonSchema.array(items: JsonSchema.string()),
      },
      additionalProperties: false,
    );
JsonObject _ruleListSchema(bool withTags) => JsonSchema.object(
      properties: {
        'cursor': JsonSchema.string(),
        'pageSize': JsonSchema.integer(minimum: 1, maximum: _maximumPageSize),
        if (withTags) 'tagIds': JsonSchema.array(items: JsonSchema.string()),
      },
      additionalProperties: false,
    );
JsonObject _ruleCreateSchema(bool withTag) => JsonSchema.object(
      properties: {
        'pattern': JsonSchema.string(minLength: 1),
        if (withTag) 'tagId': JsonSchema.string(minLength: 1),
        'description': JsonSchema.string(),
      },
      required: ['pattern', if (withTag) 'tagId'],
      additionalProperties: false,
    );
JsonObject _pagedSchema() => JsonSchema.object(
      properties: {
        'items': JsonSchema.array(items: JsonSchema.fromJson(const {})),
        'nextCursor': JsonSchema.string(),
        'totalItemCount': JsonSchema.integer(),
      },
      required: ['items', 'totalItemCount'],
      additionalProperties: false,
    );
JsonObject _mutationSchema() => JsonSchema.object(
      properties: {'id': JsonSchema.string(), 'revision': JsonSchema.string(format: 'date-time')},
      required: ['id', 'revision'],
      additionalProperties: false,
    );
JsonObject _deleteSchema() => JsonSchema.object(
      properties: {'id': JsonSchema.string(), 'deletedAt': JsonSchema.string(format: 'date-time')},
      required: ['id', 'deletedAt'],
      additionalProperties: false,
    );

({int index, int size}) _page(McpToolArguments arguments) {
  final size = arguments.optionalInt('pageSize') ?? _defaultPageSize;
  if (size < 1 || size > _maximumPageSize) throw const FormatException('pageSize must be between 1 and 200.');
  final cursor = arguments.optionalString('cursor');
  final index = cursor == null ? 0 : int.tryParse(cursor);
  if (index == null || index < 0) throw const FormatException('cursor is invalid.');
  return (index: index, size: size);
}

Map<String, dynamic> _paged(Iterable<Map<String, dynamic>> items, ({int index, int size}) page, int total) => {
      'items': items.toList(growable: false),
      if ((page.index + 1) * page.size < total) 'nextCursor': '${page.index + 1}',
      'totalItemCount': total,
    };

({DateTime start, DateTime end}) _requiredRange(McpToolArguments arguments, String from, String to) {
  final start = _date(arguments, from);
  final end = _date(arguments, to).add(const Duration(days: 1));
  if (!end.isAfter(start) || end.difference(start).inDays > _maximumRangeDays) {
    throw const FormatException('The date range must be ordered and no longer than 366 days.');
  }
  return (start: start, end: end);
}

({DateTime start, DateTime end})? _optionalRange(McpToolArguments arguments, String from, String to) {
  if (!arguments.contains(from) && !arguments.contains(to)) return null;
  if (!arguments.contains(from) || !arguments.contains(to))
    throw FormatException('$from and $to must be supplied together.');
  return _requiredRange(arguments, from, to);
}

DateTime _date(McpToolArguments arguments, String field) {
  final value = arguments.requireString(field);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) throw FormatException('$field must be YYYY-MM-DD.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) throw FormatException('$field is invalid.');
  return parsed;
}

DateTime _instant(McpToolArguments arguments, String field) {
  final value = arguments.requireString(field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$field must be an ISO-8601 instant with an offset.');
  }
  return parsed.toUtc();
}

List<String>? _strings(McpToolArguments arguments, String field) {
  final values = arguments.optionalList(field);
  if (values == null) return null;
  if (values.any((value) => value is! String || value.isEmpty)) throw FormatException('$field must contain strings.');
  return List<String>.unmodifiable(values.cast<String>());
}

({DateTime? start, DateTime? end}) _optionalBounds(McpToolArguments arguments, String from, String to) {
  final start = arguments.contains(from) ? _date(arguments, from) : null;
  final end = arguments.contains(to) ? _date(arguments, to).add(const Duration(days: 1)) : null;
  if (start != null && end != null) {
    if (!end.isAfter(start) || end.difference(start).inDays > _maximumRangeDays) {
      throw const FormatException('The date range must be ordered and no longer than 366 days.');
    }
  }
  return (start: start, end: end);
}

OptionalUpdate<String> _optionalUpdate(McpToolArguments arguments, String field) =>
    arguments.contains(field) ? OptionalUpdate.value(arguments.optionalString(field)) : const OptionalUpdate.absent();

List<SortOptionWithTranslationKey<AppUsageSortFields>>? _sort(List<dynamic>? values) {
  if (values == null) return null;
  return List.unmodifiable(values.map((value) {
    if (value is! Map) throw const FormatException('sort must contain objects.');
    return _parseSort(Map<String, dynamic>.from(value));
  }));
}

SortOptionWithTranslationKey<AppUsageSortFields>? _group(Map<String, dynamic>? value) =>
    value == null ? null : _parseSort(value);

SortOptionWithTranslationKey<AppUsageSortFields> _parseSort(Map<String, dynamic> value) {
  final field = value['field'];
  final direction = value['direction'];
  if (field is! String || direction is! String) {
    throw const FormatException('sort field and direction are required.');
  }
  return SortOptionWithTranslationKey(
    field: AppUsageSortFields.values.byName(field),
    translationKey: field,
    direction: direction == 'desc' ? SortDirection.desc : SortDirection.asc,
  );
}

JsonObject _sortSchema() => JsonSchema.object(
      properties: {
        'field': JsonSchema.string(enumValues: ['duration', 'name', 'device', 'tag']),
        'direction': JsonSchema.string(enumValues: ['asc', 'desc']),
      },
      required: ['field', 'direction'],
      additionalProperties: false,
    );

Map<String, dynamic> _tagJson(AppUsageTagListItem tag) => {
      'id': tag.tagId,
      'name': tag.tagName,
      'color': tag.tagColor,
      'order': tag.tagOrder,
    };

String _revision(DateTime createdAt, DateTime? modifiedAt) => (modifiedAt ?? createdAt).toUtc().toIso8601String();
