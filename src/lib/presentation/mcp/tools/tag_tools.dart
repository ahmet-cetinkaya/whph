import 'package:acore/acore.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/set_tag_relationships_command.dart';
import 'package:whph/core/application/features/tags/commands/update_tag_command.dart';
import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tags/queries/get_elements_by_time_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

const _readAnnotations = ToolAnnotations(
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
);
const _addAnnotations = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: false,
  openWorldHint: false,
);
const _mutationAnnotations = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: true,
  openWorldHint: false,
);
const _deleteAnnotations = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: false,
  openWorldHint: false,
);

List<McpToolDefinition> buildTagTools(
  Mediator mediator, {
  required IMcpRequestContext requestContext,
}) =>
    [
      _tagListTool(mediator),
      _tagReadTool(mediator),
      _tagCreateTool(mediator, requestContext),
      _tagUpdateTool(mediator, requestContext),
      _tagDeleteTool(mediator, requestContext),
      _tagRelationshipsTool(mediator, requestContext),
      _tagTimeAnalysisTool(mediator, requestContext),
      _tagElementsTool(mediator, requestContext),
    ];

McpToolDefinition _tagListTool(Mediator mediator) => McpToolDefinition(
      name: 'whph_tags_list',
      description:
          'Lists tags and their direct related tags with deterministic pagination.',
      inputSchema: _object({
        'cursor': JsonSchema.string(),
        'pageSize': JsonSchema.integer(minimum: 1, maximum: 200),
        'search': JsonSchema.string(),
        'relatedTagIds': _stringArray(),
        'isArchived': JsonSchema.boolean(),
        'sort': _enum(['name', 'createdDate', 'modifiedDate', 'type']),
        'groupBy': _enum(['name', 'createdDate', 'modifiedDate', 'type']),
      }),
      outputSchema: _pagedSchema(_tagSummarySchema),
      annotations: _readAnnotations,
      requiredScopes: const {McpScopes.tagsRead},
      handler: (arguments, extra) => _run(() async {
        final pageSize = arguments.optionalInt('pageSize') ?? 50;
        final page = _pageIndex(arguments.optionalString('cursor'));
        final response = await mediator
            .send<GetListTagsQuery, GetListTagsQueryResponse>(GetListTagsQuery(
          pageIndex: page,
          pageSize: pageSize,
          search: arguments.optionalString('search'),
          filterByTags: _strings(arguments, 'relatedTagIds'),
          showArchived: arguments.optionalBool('isArchived') ?? false,
          sortBy: _sort(arguments.optionalString('sort')),
          groupBy: _sortOption(arguments.optionalString('groupBy')),
          enableGrouping: arguments.contains('groupBy'),
        ));
        return {
          'items': response.items.map(_tagListJson).toList(),
          if ((page + 1) * pageSize < response.totalItemCount)
            'nextCursor': '${page + 1}',
        };
      }),
    );

McpToolDefinition _tagReadTool(Mediator mediator) => McpToolDefinition(
      name: 'whph_tags_read',
      description: 'Reads a tag and all direct related tags.',
      inputSchema: _object({'id': _idSchema}, required: ['id']),
      outputSchema: _tagReadSchema,
      annotations: _readAnnotations,
      requiredScopes: const {McpScopes.tagsRead},
      handler: (arguments, extra) => _run(() async {
        final id = arguments.requireString('id');
        final tag = await mediator
            .send<GetTagQuery, GetTagQueryResponse>(GetTagQuery(id: id));
        final related = <Map<String, dynamic>>[];
        var page = 0;
        while (true) {
          final relations = await mediator
              .send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(
            GetListTagTagsQuery(
                primaryTagId: id, pageIndex: page, pageSize: 200),
          );
          related.addAll(relations.items.map((item) => {
                'id': item.secondaryTagId,
                'name': item.secondaryTagName,
                if (item.secondaryTagColor != null)
                  'color': item.secondaryTagColor,
                'type': item.secondaryTagType.value,
              }));
          if (related.length >= relations.totalItemCount) break;
          page++;
        }
        return {
          ..._tagJson(tag.id, tag.name, tag.color, tag.type, tag.isArchived,
              tag.modifiedDate, tag.createdDate),
          'relatedTags': related,
        };
      }),
    );

McpToolDefinition _tagCreateTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tags_create',
      description: 'Creates a tag.',
      inputSchema: _object({
        'name': JsonSchema.string(minLength: 1),
        'color': _nullableString,
        'type': _tagTypeSchema,
        'isArchived': JsonSchema.boolean(),
      }, required: [
        'name',
        'type'
      ]),
      outputSchema: _idRevisionSchema,
      annotations: _addAnnotations,
      requiredScopes: const {McpScopes.tagsWrite},
      handler: (arguments, extra) => _run(() async {
        final response = await mediator
            .send<SaveTagCommand, SaveTagCommandResponse>(SaveTagCommand(
          name: arguments.requireString('name'),
          color: arguments.optionalString('color'),
          type: _tagType(arguments.requireString('type')),
          isArchived: arguments.optionalBool('isArchived') ?? false,
          authorizeCommit: () =>
              context.isAuthorized(const {McpScopes.tagsWrite}),
        ));
        return {
          'id': response.id,
          'revision': (response.modifiedDate ?? response.createdDate)
              .toUtc()
              .toIso8601String()
        };
      }),
    );

McpToolDefinition _tagUpdateTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tags_update',
      description: 'Patches a tag using optimistic revision control.',
      inputSchema: _object({
        'id': _idSchema,
        'expectedRevision': _revisionSchema,
        'name': JsonSchema.string(minLength: 1),
        'color': _nullableString,
        'type': _tagTypeSchema,
        'isArchived': JsonSchema.boolean(),
      }, required: [
        'id',
        'expectedRevision'
      ]),
      outputSchema: _idRevisionSchema,
      annotations: _mutationAnnotations,
      requiredScopes: const {McpScopes.tagsWrite},
      handler: (arguments, extra) => _run(() async {
        if (!['name', 'color', 'type', 'isArchived'].any(arguments.contains)) {
          throw McpToolException(McpToolError(
              code: McpToolErrorCode.validationError,
              message: 'At least one tag field must be supplied.'));
        }
        final color = !arguments.contains('color')
            ? const NoteContentUpdate.unchanged()
            : arguments['color'] == null
                ? const NoteContentUpdate.clear()
                : NoteContentUpdate.set(arguments.requireString('color'));
        final response = await mediator
            .send<UpdateTagCommand, UpdateTagCommandResponse>(UpdateTagCommand(
          id: arguments.requireString('id'),
          expectedRevision: _parseInstant(
              arguments.requireString('expectedRevision'), 'expectedRevision'),
          name: arguments.optionalString('name'),
          color: color,
          type: arguments.contains('type')
              ? _tagType(arguments.requireString('type'))
              : null,
          isArchived: arguments.optionalBool('isArchived'),
          authorizeCommit: () =>
              context.isAuthorized(const {McpScopes.tagsWrite}),
        ));
        return {
          'id': response.id,
          'revision': response.revision.toUtc().toIso8601String()
        };
      }),
    );

McpToolDefinition _tagDeleteTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tags_delete',
      description:
          'Atomically deletes a tag and its relationships using optimistic revision control.',
      inputSchema: _object(
          {'id': _idSchema, 'expectedRevision': _revisionSchema},
          required: ['id', 'expectedRevision']),
      outputSchema: _object({'id': _idSchema, 'deletedAt': _revisionSchema},
          required: ['id', 'deletedAt']),
      annotations: _deleteAnnotations,
      requiredScopes: const {McpScopes.tagsDelete},
      handler: (arguments, extra) => _run(() async {
        final id = arguments.requireString('id');
        await mediator
            .send<DeleteTagCommand, DeleteTagCommandResponse>(DeleteTagCommand(
          id: id,
          expectedRevision: _parseInstant(
              arguments.requireString('expectedRevision'), 'expectedRevision'),
          authorizeCommit: () =>
              context.isAuthorized(const {McpScopes.tagsDelete}),
        ));
        return {
          'id': id,
          'deletedAt': DateTime.now().toUtc().toIso8601String()
        };
      }),
    );

McpToolDefinition _tagRelationshipsTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tag_relationships_set',
      description:
          'Atomically replaces tag relationship membership and rejects self-links, duplicates, and cycles. Returned IDs use canonical ID order.',
      inputSchema: _object({
        'tagId': _idSchema,
        'expectedRevision': _revisionSchema,
        'relatedTagIds': _stringArray(),
      }, required: [
        'tagId',
        'expectedRevision',
        'relatedTagIds'
      ]),
      outputSchema: _object({
        'tagId': _idSchema,
        'relatedTagIds': _stringArray(),
        'revision': _revisionSchema,
      }, required: [
        'tagId',
        'relatedTagIds',
        'revision'
      ]),
      annotations: _mutationAnnotations,
      requiredScopes: const {McpScopes.tagsWrite},
      handler: (arguments, extra) => _run(() async {
        final response = await mediator.send<SetTagRelationshipsCommand,
            SetTagRelationshipsCommandResponse>(
          SetTagRelationshipsCommand(
            tagId: arguments.requireString('tagId'),
            expectedRevision: _parseInstant(
                arguments.requireString('expectedRevision'),
                'expectedRevision'),
            relatedTagIds: _strings(arguments, 'relatedTagIds') ?? const [],
            authorizeCommit: () =>
                context.isAuthorized(const {McpScopes.tagsWrite}),
          ),
        );
        return {
          'tagId': response.tagId,
          'relatedTagIds': response.relatedTagIds,
          'revision': response.revision.toUtc().toIso8601String(),
        };
      }),
    );

McpToolDefinition _tagTimeAnalysisTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tag_time_analysis',
      description:
          'Returns tag time totals only after checking read access for every requested contributing category.',
      inputSchema: _analysisInput(includeTagId: true),
      outputSchema: _object({
        'items': JsonSchema.array(items: _timeTagSchema),
        'tagId': _idSchema,
        'totalDurationSeconds': JsonSchema.integer(minimum: 0),
      }, required: [
        'items',
        'totalDurationSeconds'
      ]),
      annotations: _readAnnotations,
      requiredScopes: const {McpScopes.tagsRead},
      handler: (arguments, extra) => _run(() async {
        final categories = _categories(arguments);
        await _authorizeCategories(categories, context);
        final (from, to) = _analysisRange(arguments);
        final tagIds = _strings(arguments, 'tagIds') ?? const [];
        final tagId = arguments.optionalString('tagId');
        final filters = tagId == null ? tagIds : {...tagIds, tagId}.toList();
        final response = await mediator.send<GetTopTagsByTimeQuery,
            GetTopTagsByTimeQueryResponse>(GetTopTagsByTimeQuery(
          startDate: from,
          endDate: to,
          limit: arguments.optionalInt('limit') ?? 50,
          filterByTags: filters.isEmpty ? null : filters,
          filterByIsArchived:
              arguments.optionalBool('includeArchived') ?? false,
          categories: categories,
        ));
        return {
          'items': response.items
              .map((item) => {
                    'id': item.tagId,
                    'name': item.tagName,
                    if (item.tagColor != null) 'color': item.tagColor,
                    'category': _categoryName(item.category),
                    'durationSeconds': item.duration,
                  })
              .toList(),
          if (tagId != null) 'tagId': tagId,
          'totalDurationSeconds': response.totalDuration,
        };
      }),
    );

McpToolDefinition _tagElementsTool(
        Mediator mediator, IMcpRequestContext context) =>
    McpToolDefinition(
      name: 'whph_tag_elements_by_time',
      description:
          'Returns task, habit, and usage elements by time only with every selected feature read grant.',
      inputSchema: _analysisInput(),
      outputSchema: _object({
        'items': JsonSchema.array(items: _elementSchema),
        'totalDurationSeconds': JsonSchema.integer(minimum: 0),
      }, required: [
        'items',
        'totalDurationSeconds'
      ]),
      annotations: _readAnnotations,
      requiredScopes: const {McpScopes.tagsRead},
      handler: (arguments, extra) => _run(() async {
        final categories = _categories(arguments);
        await _authorizeCategories(categories, context);
        final (from, to) = _analysisRange(arguments);
        final response = await mediator.send<GetElementsByTimeQuery,
            GetElementsByTimeQueryResponse>(GetElementsByTimeQuery(
          startDate: from,
          endDate: to,
          limit: arguments.optionalInt('limit') ?? 50,
          filterByTags: _strings(arguments, 'tagIds'),
          filterByIsArchived:
              arguments.optionalBool('includeArchived') ?? false,
          categories: categories,
        ));
        return {
          'items': response.items
              .map((item) => {
                    'id': item.id,
                    'name': item.name,
                    'durationSeconds': item.duration,
                    'category': _categoryName(item.category),
                    if (item.color != null) 'color': item.color,
                    if (item.tagId != null)
                      'tag': {
                        'id': item.tagId,
                        if (item.tagName != null) 'name': item.tagName,
                        if (item.tagColor != null) 'color': item.tagColor,
                      },
                  })
              .toList(),
          'totalDurationSeconds': response.totalDuration,
        };
      }),
    );

Future<void> _authorizeCategories(
  List<TagTimeCategory> categories,
  IMcpRequestContext context,
) async {
  final expanded = categories.contains(TagTimeCategory.all)
      ? const [
          TagTimeCategory.tasks,
          TagTimeCategory.habits,
          TagTimeCategory.appUsage
        ]
      : categories;
  final scopes = expanded
      .map((category) => switch (category) {
            TagTimeCategory.tasks => McpScopes.tasksRead,
            TagTimeCategory.habits => McpScopes.habitsRead,
            TagTimeCategory.appUsage => McpScopes.usageRead,
            TagTimeCategory.all => throw StateError('Unexpanded category'),
          })
      .toSet();
  if (!await context.isAuthorized(scopes)) {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.permissionDenied,
        message: 'A selected time category is not granted.'));
  }
}

List<TagTimeCategory> _categories(McpToolArguments arguments) {
  final values = _strings(arguments, 'categories');
  if (values == null || values.isEmpty) return const [TagTimeCategory.all];
  return List.unmodifiable(values.map((value) => switch (value) {
        'tasks' => TagTimeCategory.tasks,
        'habits' => TagTimeCategory.habits,
        'usage' => TagTimeCategory.appUsage,
        _ => throw McpToolException(McpToolError(
            code: McpToolErrorCode.validationError,
            message: 'Invalid category.')),
      }));
}

Future<CallToolResult> _run(
    Future<Map<String, dynamic>> Function() operation) async {
  try {
    return McpToolResult.success(await operation());
  } on TagRevisionConflictException {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.conflict,
        message: 'The tag changed. Read it and retry.'));
  } on TagRelationshipCycleException {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.validationError,
        message: 'Tag relationships cannot contain a cycle.'));
  } on BusinessException catch (error) {
    throw McpToolException(
        McpToolError(code: McpToolErrorCode.notFound, message: error.message));
  } on StateError catch (error) {
    throw McpToolException(
        McpToolError(code: McpToolErrorCode.notFound, message: error.message));
  } on MutationAuthorizationException {
    throw McpToolException(McpToolError(
      code: McpToolErrorCode.permissionDenied,
      message: 'Authorization changed before commit.',
    ));
  }
}

DateTime _parseInstant(String value, String field) {
  if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.validationError,
        message: '$field must include an offset.'));
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null)
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.validationError, message: 'Invalid $field.'));
  return parsed.toUtc();
}

(DateTime, DateTime) _analysisRange(McpToolArguments arguments) {
  final from = _parseInstant(arguments.requireString('from'), 'from');
  final to = _parseInstant(arguments.requireString('to'), 'to');
  if (from.isAfter(to)) {
    throw McpToolException(McpToolError(
      code: McpToolErrorCode.validationError,
      message: 'from must not be after to.',
    ));
  }
  return (from, to);
}

int _pageIndex(String? cursor) {
  if (cursor == null) return 0;
  final page = int.tryParse(cursor);
  if (page == null || page < 0)
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.validationError, message: 'Invalid cursor.'));
  return page;
}

List<String>? _strings(McpToolArguments arguments, String name) {
  final values = arguments.optionalList(name);
  if (values == null) return null;
  if (values.any((value) => value is! String) ||
      values.toSet().length != values.length) {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.validationError,
        message: 'Argument "$name" must contain unique strings.'));
  }
  return List.unmodifiable(values.cast<String>());
}

List<SortOption<TagSortFields>>? _sort(String? value) =>
    value == null ? null : [_sortOption(value)!];
SortOption<TagSortFields>? _sortOption(String? value) => value == null
    ? null
    : SortOption(
        field: TagSortFields.values.byName(value),
        direction: SortDirection.asc);
TagType _tagType(String value) => TagType.values.byName(value);
String _categoryName(TagTimeCategory category) =>
    category == TagTimeCategory.appUsage ? 'usage' : category.name;

Map<String, dynamic> _tagListJson(TagListItem tag) => {
      'id': tag.id,
      'name': tag.name,
      if (tag.color != null) 'color': tag.color,
      'type': tag.type.value,
      'isArchived': tag.isArchived,
      'relatedTags':
          tag.relatedTags.map((related) => _tagListJson(related)).toList(),
      'revision':
          (tag.modifiedDate ?? tag.createdDate!).toUtc().toIso8601String(),
      if (tag.groupName != null) 'group': tag.groupName,
    };

Map<String, dynamic> _tagJson(
  String id,
  String name,
  String? color,
  TagType type,
  bool isArchived,
  DateTime? modified,
  DateTime created,
) =>
    {
      'id': id,
      'name': name,
      if (color != null) 'color': color,
      'type': type.value,
      'isArchived': isArchived,
      'revision': (modified ?? created).toUtc().toIso8601String(),
    };

JsonObject _analysisInput({bool includeTagId = false}) => _object({
      if (includeTagId) 'tagId': _idSchema,
      'from': _revisionSchema,
      'to': _revisionSchema,
      'limit': JsonSchema.integer(minimum: 1, maximum: 200),
      'tagIds': _stringArray(),
      'includeArchived': JsonSchema.boolean(),
      'categories': JsonSchema.array(
          items: _enum(['tasks', 'habits', 'usage']),
          uniqueItems: true,
          maxItems: 3),
    }, required: [
      'from',
      'to'
    ]);

JsonObject _object(Map<String, JsonSchema> properties,
        {List<String>? required}) =>
    JsonSchema.object(
        properties: properties,
        required: required,
        additionalProperties: false);
JsonSchema _enum(List<String> values) =>
    JsonSchema.fromJson({'type': 'string', 'enum': values});
JsonSchema _stringArray() =>
    JsonSchema.array(items: _idSchema, uniqueItems: true, maxItems: 200);
final _nullableString = JsonSchema.fromJson({
  'type': ['string', 'null']
});
final _idSchema = JsonSchema.string(minLength: 1, maxLength: 256);
final _revisionSchema = JsonSchema.string(format: 'date-time');
final _tagTypeSchema = _enum(['label', 'context', 'project']);
final _relatedTagSchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'color': JsonSchema.string(),
  'type': _tagTypeSchema,
}, required: [
  'id',
  'name',
  'type'
]);
final _tagSummarySchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'color': JsonSchema.string(),
  'type': _tagTypeSchema,
  'isArchived': JsonSchema.boolean(),
  'relatedTags': JsonSchema.array(items: _relatedTagSchema),
  'revision': _revisionSchema,
  'group': JsonSchema.string(),
}, required: [
  'id',
  'name',
  'type',
  'isArchived',
  'relatedTags',
  'revision'
]);
final _tagReadSchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'color': JsonSchema.string(),
  'type': _tagTypeSchema,
  'isArchived': JsonSchema.boolean(),
  'relatedTags': JsonSchema.array(items: _relatedTagSchema),
  'revision': _revisionSchema,
}, required: [
  'id',
  'name',
  'type',
  'isArchived',
  'relatedTags',
  'revision'
]);
final _timeTagSchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'color': JsonSchema.string(),
  'category': _enum(['tasks', 'habits', 'usage']),
  'durationSeconds': JsonSchema.integer(minimum: 0),
}, required: [
  'id',
  'name',
  'category',
  'durationSeconds'
]);
final _elementTagSchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'color': JsonSchema.string()
}, required: [
  'id'
]);
final _elementSchema = _object({
  'id': _idSchema,
  'name': JsonSchema.string(),
  'durationSeconds': JsonSchema.integer(minimum: 0),
  'category': _enum(['tasks', 'habits', 'usage']),
  'color': JsonSchema.string(),
  'tag': _elementTagSchema,
}, required: [
  'id',
  'name',
  'durationSeconds',
  'category'
]);
final _idRevisionSchema = _object(
    {'id': _idSchema, 'revision': _revisionSchema},
    required: ['id', 'revision']);
JsonObject _pagedSchema(JsonSchema item) => _object({
      'items': JsonSchema.array(items: item),
      'nextCursor': JsonSchema.string(),
    }, required: [
      'items'
    ]);
