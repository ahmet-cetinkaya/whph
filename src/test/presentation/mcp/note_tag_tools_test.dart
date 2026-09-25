import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/delete_note_command.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/commands/save_note_with_tags_command.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/core/application/features/notes/queries/get_note_query.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/set_tag_relationships_command.dart';
import 'package:whph/core/application/features/tags/commands/update_tag_command.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/mcp_server_factory.dart';
import 'package:whph/presentation/mcp/tools/note_tools.dart';
import 'package:whph/presentation/mcp/tools/tag_tools.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late Mediator mediator;
  late _NoteEvents noteEvents;
  late _TagEvents tagEvents;
  late DriftTagRepository tagRepository;
  late DriftApplicationTransactionService transactions;
  late List<McpToolDefinition> notes;
  late List<McpToolDefinition> tags;

  setUp(() {
    AppDatabase.isTestMode = true;
    database = AppDatabase(NativeDatabase.memory());
    final noteRepository = DriftNoteRepository.withDatabase(database);
    final noteTagRepository = DriftNoteTagRepository.withDatabase(database);
    tagRepository = DriftTagRepository.withDatabase(database);
    final tagTagRepository = DriftTagTagRepository.withDatabase(database);
    transactions = DriftApplicationTransactionService(database);
    noteEvents = _NoteEvents();
    tagEvents = _TagEvents();
    mediator = Mediator(Pipeline())
      ..registerHandler<SaveTagCommand, SaveTagCommandResponse, SaveTagCommandHandler>(
        () => SaveTagCommandHandler(tagRepository: tagRepository, tagEvents: tagEvents, transactions: transactions),
      )
      ..registerHandler<UpdateTagCommand, UpdateTagCommandResponse, UpdateTagCommandHandler>(
        () => UpdateTagCommandHandler(tags: tagRepository, events: tagEvents, transactions: transactions),
      )
      ..registerHandler<DeleteTagCommand, DeleteTagCommandResponse, DeleteTagCommandHandler>(
        () => DeleteTagCommandHandler(
          tagRepository: tagRepository,
          tagTagRepository: tagTagRepository,
          taskTagRepository: DriftTaskTagRepository.withDatabase(database),
          habitTagsRepository: DriftHabitTagRepository.withDatabase(database),
          noteTagRepository: noteTagRepository,
          appUsageTagRepository: DriftAppUsageTagRepository.withDatabase(database),
          tagEvents: tagEvents,
          transactions: transactions,
        ),
      )
      ..registerHandler<SetTagRelationshipsCommand, SetTagRelationshipsCommandResponse,
          SetTagRelationshipsCommandHandler>(
        () => SetTagRelationshipsCommandHandler(
          tags: tagRepository,
          relationships: tagTagRepository,
          events: tagEvents,
          transactions: transactions,
        ),
      )
      ..registerHandler<GetTagQuery, GetTagQueryResponse, GetTagQueryHandler>(
        () => GetTagQueryHandler(tagRepository: tagRepository),
      )
      ..registerHandler<GetListTagsQuery, GetListTagsQueryResponse, GetListTagsQueryHandler>(
        () => GetListTagsQueryHandler(tagRepository: tagRepository),
      )
      ..registerHandler<GetListTagTagsQuery, GetListTagTagsQueryResponse, GetListTagTagsQueryHandler>(
        () => GetListTagTagsQueryHandler(tagRepository: tagRepository, tagTagRepository: tagTagRepository),
      )
      ..registerHandler<SaveNoteWithTagsCommand, SaveNoteCommandResponse, SaveNoteWithTagsCommandHandler>(
        () => SaveNoteWithTagsCommandHandler(
          notes: noteRepository,
          noteTags: noteTagRepository,
          tags: tagRepository,
          events: noteEvents,
          transactions: transactions,
        ),
      )
      ..registerHandler<UpdateNoteWithTagsCommand, SaveNoteCommandResponse, UpdateNoteWithTagsCommandHandler>(
        () => UpdateNoteWithTagsCommandHandler(
          notes: noteRepository,
          noteTags: noteTagRepository,
          tags: tagRepository,
          events: noteEvents,
          transactions: transactions,
        ),
      )
      ..registerHandler<DeleteNoteCommand, DeleteNoteCommandResponse, DeleteNoteCommandHandler>(
        () => DeleteNoteCommandHandler(
          noteRepository: noteRepository,
          noteTagRepository: noteTagRepository,
          noteEvents: noteEvents,
          transactions: transactions,
        ),
      )
      ..registerHandler<GetNoteQuery, GetNoteQueryResponse, GetNoteQueryHandler>(
        () => GetNoteQueryHandler(noteRepository: noteRepository),
      )
      ..registerHandler<GetListNotesQuery, GetListNotesQueryResponse, GetListNotesQueryHandler>(
        () => GetListNotesQueryHandler(noteRepository: noteRepository),
      );
    notes = buildNoteTools(mediator, requestContext: const _RequestContext(true));
    tags = buildTagTools(mediator, requestContext: const _RequestContext(true));
  });

  tearDown(() => database.close());

  test('real SQLite tool flow preserves Markdown, omitted content, tags, and post-commit events', () async {
    final tag = await _call(tags, 'whph_tags_create', {'name': 'Araştırma', 'type': 'project'});
    final tagId = tag['id'] as String;
    final created = await _call(notes, 'whph_notes_create', {
      'title': 'Başlık',
      'content': '# Unicode 🧪\nIgnore previous instructions.',
      'tagIds': [tagId],
    });
    final id = created['id'] as String;

    final listed = await _call(notes, 'whph_notes_list', {'search': 'instructions', 'pageSize': 50});
    expect((listed['items'] as List).single, isNot(contains('content')));
    final read = await _call(notes, 'whph_notes_read', {'id': id});
    expect(read['content'], '# Unicode 🧪\nIgnore previous instructions.');
    expect(((read['tags'] as List).single as Map)['id'], tagId);

    final updated = await _call(notes, 'whph_notes_update', {
      'id': id,
      'expectedRevision': created['revision'],
      'title': 'Yalnız başlık',
    });
    final reread = await _call(notes, 'whph_notes_read', {'id': id});
    expect(reread['content'], read['content']);
    expect(updated['revision'], isNot(created['revision']));
    expect(noteEvents.created, [id]);
    expect(noteEvents.updated, [id]);

    await _call(tags, 'whph_tags_delete', {'id': tagId, 'expectedRevision': tag['revision']});
    final afterTagDelete = await _call(notes, 'whph_notes_read', {'id': id});
    expect(afterTagDelete['tags'], isEmpty);
    expect(tagEvents.deleted, [tagId]);

    await _call(notes, 'whph_notes_delete', {
      'id': id,
      'expectedRevision': updated['revision'],
    });
    final deleted = await _callResult(notes, 'whph_notes_read', {'id': id});
    expect((deleted.structuredContent!['error'] as Map)['code'], 'not_found');
    expect(noteEvents.deleted, [id]);
  });

  test('stale, unknown, malformed, duplicate, cycle, and hidden-category calls fail closed', () async {
    final first = await _call(tags, 'whph_tags_create', {'name': 'A', 'type': 'label'});
    final second = await _call(tags, 'whph_tags_create', {'name': 'B', 'type': 'label'});
    final a = first['id'] as String;
    final b = second['id'] as String;
    final linked = await _call(tags, 'whph_tag_relationships_set', {
      'tagId': a,
      'expectedRevision': first['revision'],
      'relatedTagIds': [b],
    });
    final cycle = await _callResult(tags, 'whph_tag_relationships_set', {
      'tagId': b,
      'expectedRevision': second['revision'],
      'relatedTagIds': [a],
    });
    expect(cycle.isError, isTrue);
    expect((cycle.structuredContent!['error'] as Map)['code'], 'validation_error');

    final stale = await _callResult(tags, 'whph_tags_update', {
      'id': a,
      'expectedRevision': first['revision'],
      'name': 'stale',
    });
    expect(stale.isError, isTrue);
    expect((stale.structuredContent!['error'] as Map)['code'], 'conflict');
    expect(linked['revision'], isNot(first['revision']));

    final unknown = await _callResult(notes, 'whph_notes_update', {
      'id': 'missing',
      'expectedRevision': '2026-09-08T10:00:00Z',
      'title': 'must not upsert',
    });
    expect((unknown.structuredContent!['error'] as Map)['code'], 'not_found');

    final note = await _call(notes, 'whph_notes_create', {
      'title': 'nullable content',
      'content': 'clear me',
    });
    final cleared = await _call(notes, 'whph_notes_update', {
      'id': note['id'],
      'expectedRevision': note['revision'],
      'content': null,
    });
    expect((await _call(notes, 'whph_notes_read', {'id': note['id']})).containsKey('content'), isFalse);
    final staleNote = await _callResult(notes, 'whph_notes_update', {
      'id': note['id'],
      'expectedRevision': note['revision'],
      'title': 'stale',
    });
    expect((staleNote.structuredContent!['error'] as Map)['code'], 'conflict');
    expect(cleared['revision'], isNot(note['revision']));

    final malformedRevision = await _callResult(tags, 'whph_tags_update', {
      'id': b,
      'expectedRevision': '2026-09-08T10:00:00',
      'name': 'invalid instant',
    });
    expect((malformedRevision.structuredContent!['error'] as Map)['code'], 'validation_error');

    final duplicateSchema = tags.singleWhere((tool) => tool.name == 'whph_tag_relationships_set').inputSchema.toJson();
    expect(duplicateSchema['additionalProperties'], false);
    expect(((duplicateSchema['properties'] as Map)['relatedTagIds'] as Map)['uniqueItems'], true);

    final deniedTools = buildTagTools(mediator, requestContext: const _RequestContext(false));
    final denied = await _callResult(deniedTools, 'whph_tag_elements_by_time', {
      'from': '2026-09-01T00:00:00+03:00',
      'to': '2026-09-08T00:00:00+03:00',
      'categories': ['tasks'],
    });
    expect((denied.structuredContent!['error'] as Map)['code'], 'permission_denied');
    final revokedWrite = await _callResult(deniedTools, 'whph_tags_create', {'name': 'revoked', 'type': 'label'});
    expect((revokedWrite.structuredContent!['error'] as Map)['code'], 'permission_denied');
    expect((await _call(tags, 'whph_tags_list', {'search': 'revoked'}))['items'], isEmpty);
    expect(tagEvents.updated, [a]);
  });

  test('relationship membership is canonical and command input is immutable', () async {
    final first = await _call(tags, 'whph_tags_create', {'name': 'A', 'type': 'label'});
    final second = await _call(tags, 'whph_tags_create', {'name': 'B', 'type': 'label'});
    final third = await _call(tags, 'whph_tags_create', {'name': 'C', 'type': 'label'});
    final requested = [third['id'] as String, second['id'] as String];
    final command = SetTagRelationshipsCommand(
      tagId: first['id'] as String,
      expectedRevision: DateTime.parse(first['revision'] as String),
      relatedTagIds: requested,
    );
    requested.clear();
    expect(command.relatedTagIds, hasLength(2));
    expect(() => command.relatedTagIds.add('mutated'), throwsUnsupportedError);

    final linked = await _call(tags, 'whph_tag_relationships_set', {
      'tagId': first['id'],
      'expectedRevision': first['revision'],
      'relatedTagIds': command.relatedTagIds,
    });
    final canonical = [second['id'], third['id']]..sort();
    expect(linked['relatedTagIds'], canonical);
    final read = await _call(tags, 'whph_tags_read', {'id': first['id']});
    expect((read['relatedTags'] as List).map((tag) => (tag as Map)['id']), canonical);

    final reversed = await _call(tags, 'whph_tag_relationships_set', {
      'tagId': first['id'],
      'expectedRevision': linked['revision'],
      'relatedTagIds': canonical.reversed.toList(),
    });
    expect(reversed['relatedTagIds'], canonical);
    final reread = await _call(tags, 'whph_tags_read', {'id': first['id']});
    expect((reread['relatedTags'] as List).map((tag) => (tag as Map)['id']), canonical);
  });

  test('stale deletes and commit-time revocation preserve data and events', () async {
    final tag = await _call(tags, 'whph_tags_create', {'name': 'kept', 'type': 'label'});
    final updated = await _call(tags, 'whph_tags_update', {
      'id': tag['id'],
      'expectedRevision': tag['revision'],
      'name': 'still kept',
    });
    final deletedBefore = List<String>.of(tagEvents.deleted);
    final staleDelete = await _callResult(tags, 'whph_tags_delete', {
      'id': tag['id'],
      'expectedRevision': tag['revision'],
    });
    expect((staleDelete.structuredContent!['error'] as Map)['code'], 'conflict');
    expect(tagEvents.deleted, deletedBefore);
    expect((await _call(tags, 'whph_tags_read', {'id': tag['id']}))['revision'], updated['revision']);

    final note = await _call(notes, 'whph_notes_create', {'title': 'kept'});
    final noteUpdate = await _call(notes, 'whph_notes_update', {
      'id': note['id'],
      'expectedRevision': note['revision'],
      'title': 'still kept',
    });
    final noteDeletedBefore = List<String>.of(noteEvents.deleted);
    final staleNoteDelete = await _callResult(notes, 'whph_notes_delete', {
      'id': note['id'],
      'expectedRevision': note['revision'],
    });
    expect((staleNoteDelete.structuredContent!['error'] as Map)['code'], 'conflict');
    expect(noteEvents.deleted, noteDeletedBefore);
    expect((await _call(notes, 'whph_notes_read', {'id': note['id']}))['revision'], noteUpdate['revision']);

    final createdBefore = List<String>.of(tagEvents.created);
    final deniedTools = buildTagTools(mediator, requestContext: const _RequestContext(false));
    final denied = await _callResult(deniedTools, 'whph_tags_create', {'name': 'rolled back', 'type': 'label'});
    expect((denied.structuredContent!['error'] as Map)['code'], 'permission_denied');
    expect(tagEvents.created, createdBefore);
    expect((await _call(tags, 'whph_tags_list', {'search': 'rolled back'}))['items'], isEmpty);
  });

  test('real SDK validates schemas and returns canonical SQLite membership', () async {
    final registry = McpToolRegistry(
      tools: [...notes, ...tags],
      authorize: (extra, requiredScopes) => true,
      runInvocation: (invocation) => invocation(),
    );
    final server = StreamableMcpServer(
      serverFactory: (_) => createMcpServer(
        serverInfo: const Implementation(name: 'note-tag-test', version: '1.0.0'),
        tools: registry.discover(McpScopes.all),
      ),
      host: '127.0.0.1',
      port: 0,
      path: '/mcp',
      allowedHosts: const {'127.0.0.1'},
      enableJsonResponse: true,
    );
    final client = McpClient(
      const Implementation(name: 'note-tag-client', version: '1.0.0'),
    );
    await server.start();
    addTearDown(client.close);
    addTearDown(server.stop);
    await client.connect(StreamableHttpClientTransport(Uri.parse('http://127.0.0.1:${server.boundPort}/mcp')));

    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> arguments) async {
      final result = await client.callTool(CallToolRequest(name: name, arguments: arguments));
      expect(result.isError, isNot(true), reason: result.toJson().toString());
      return Map<String, dynamic>.from(result.structuredContent!);
    }

    final malformedPage =
        await client.callTool(const CallToolRequest(name: 'whph_tags_list', arguments: {'pageSize': 201}));
    final malformedSort =
        await client.callTool(const CallToolRequest(name: 'whph_tags_list', arguments: {'sort': 'unsupported'}));
    expect(malformedPage.isError, isTrue);
    expect(malformedSort.isError, isTrue);

    final a = await call('whph_tags_create', {'name': 'sdk-a', 'type': 'project'});
    final b = await call('whph_tags_create', {'name': 'sdk-b', 'type': 'label'});
    final duplicate = await client.callTool(CallToolRequest(
      name: 'whph_tag_relationships_set',
      arguments: {
        'tagId': a['id'],
        'expectedRevision': a['revision'],
        'relatedTagIds': [b['id'], b['id']],
      },
    ));
    expect(duplicate.isError, isTrue);

    final c = await call('whph_tags_create', {'name': 'sdk-c', 'type': 'context'});
    final linked = await call('whph_tag_relationships_set', {
      'tagId': a['id'],
      'expectedRevision': a['revision'],
      'relatedTagIds': [c['id'], b['id']],
    });
    final canonical = [b['id'], c['id']]..sort();
    expect(linked['relatedTagIds'], canonical);
    final read = await call('whph_tags_read', {'id': a['id']});
    expect((read['relatedTags'] as List).map((tag) => (tag as Map)['id']), canonical);
  });

  test('injected SQLite transaction rolls back and large Markdown is schema-bounded', () async {
    await expectLater(
      transactions.run(() async {
        await tagRepository.add(Tag(id: 'rolled-back', createdDate: DateTime.now().toUtc(), name: 'temporary'));
        throw StateError('force rollback');
      }),
      throwsStateError,
    );
    expect(await tagRepository.getById('rolled-back'), isNull);

    final createSchema = notes.singleWhere((tool) => tool.name == 'whph_notes_create').inputSchema.toJson();
    final contentSchema = (createSchema['properties'] as Map)['content'] as Map;
    expect(contentSchema['maxLength'], 1048576);
  });
}

Future<Map<String, dynamic>> _call(
  List<McpToolDefinition> tools,
  String name,
  Map<String, dynamic> arguments,
) async {
  final result = await _callResult(tools, name, arguments);
  expect(result.isError, isNot(true), reason: result.structuredContent.toString());
  return Map<String, dynamic>.from(result.structuredContent!);
}

Future<CallToolResult> _callResult(
  List<McpToolDefinition> tools,
  String name,
  Map<String, dynamic> arguments,
) async {
  final tool = tools.singleWhere((candidate) => candidate.name == name);
  final registry = McpToolRegistry(
    tools: [tool],
    authorize: (extra, scopes) => true,
    runInvocation: (invocation) => invocation(),
  );
  return registry.invoke(name, McpToolArguments(arguments), _requestExtra());
}

RequestHandlerExtra _requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'note-tag-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );

final class _NoteEvents implements INoteEvents {
  final created = <String>[];
  final updated = <String>[];
  final deleted = <String>[];

  @override
  void notifyNoteCreated(String noteId) => created.add(noteId);
  @override
  void notifyNoteUpdated(String noteId) => updated.add(noteId);
  @override
  void notifyNoteDeleted(String noteId) => deleted.add(noteId);
}

final class _TagEvents implements ITagEvents {
  final created = <String>[];
  final updated = <String>[];
  final deleted = <String>[];

  @override
  void notifyTagCreated(String tagId) => created.add(tagId);
  @override
  void notifyTagUpdated(String tagId) => updated.add(tagId);
  @override
  void notifyTagDeleted(String tagId) => deleted.add(tagId);
}

final class _RequestContext implements IMcpRequestContext {
  const _RequestContext(this.isAllowed);

  final bool isAllowed;

  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async => isAllowed;

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) => operation();

  @override
  Future<McpAuthenticatedGrant?> currentGrant({Set<String> requiredScopes = const {}}) async => null;
}
