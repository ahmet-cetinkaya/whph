// T23 carry-over 3 (FR-051, deferred from T18 acceptance 4): one write of each
// MCP write-tool family, made through the real tool layer, real handlers and a
// real v38 Drift database, leaves `sync_clock` rows for the table it wrote, so
// the sync capture triggers fire for MCP writes.
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/mcp_tools.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';

import '../../shared/features/sync/sync_container_test_support.dart';

class _AllowAll implements IMcpRequestContext {
  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async => true;

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) => operation();

  @override
  Future<McpAuthenticatedGrant?> currentGrant({Set<String> requiredScopes = const {}}) async => null;
}

void main() {
  late Directory root;
  late AppDatabase database;
  late List<McpToolDefinition> tools;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp-capture-');
    final IContainer container = await buildSyncTestContainer(root);
    database = AppDatabase.instance();
    tools = buildMcpTools(container, _AllowAll());
  });
  tearDown(() => root.delete(recursive: true));

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> arguments) async {
    final registry = McpToolRegistry(
      tools: [tools.singleWhere((tool) => tool.name == name)],
      authorize: (extra, scopes) => true,
      runInvocation: (invocation) => invocation(),
    );
    final result = await registry.invoke(name, McpToolArguments(arguments), _requestExtra());
    expect(result.isError, isNot(true), reason: '$name: ${result.structuredContent}');
    return Map<String, dynamic>.from(result.structuredContent!);
  }

  Future<int> clockRows(String table) async {
    final tblId = syncTablePolicies.singleWhere((policy) => policy.tableName == table).tblId;
    final row = await database.customSelect(
      'SELECT COUNT(*) AS n FROM sync_clock c JOIN sync_row r ON r.id = c.key / $packedKeyFactor WHERE r.tbl_id = ?',
      variables: [Variable<int>(tblId)],
    ).getSingle();
    return row.read<int>('n');
  }

  Future<void> expectCaptured(String table, Future<void> Function() write) async {
    expect(await clockRows(table), 0, reason: '$table starts without clock rows');
    await write();
    expect(await clockRows(table), greaterThan(0), reason: '$table: the MCP write left no sync_clock row');
  }

  test('the sync capture triggers exist on the test database', () async {
    final triggers =
        await database.customSelect("SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'trigger'").getSingle();

    expect(triggers.read<int>('n'), greaterThan(0));
  });

  test('tasks family: task, task time record, task status', () async {
    late String taskId;
    await expectCaptured('task_table', () async {
      taskId = (await call('whph_tasks_create', {'title': 'MCP task'}))['id'] as String;
    });
    await expectCaptured('task_time_record_table', () async {
      await call('whph_task_time_records_add', {
        'taskId': taskId,
        'durationSeconds': 30,
        'occurredAt': '2026-09-09T03:00:00+03:00',
      });
    });
    await expectCaptured('task_status_table', () async {
      await call('whph_task_statuses_create', {'name': 'Waiting'});
    });
  });

  test('habits family: habit, habit record, habit time record', () async {
    late String habitId;
    await expectCaptured('habit_table', () async {
      habitId = (await call('whph_habits_create', {'name': 'Read', 'type': 'good'}))['id'] as String;
    });
    await expectCaptured('habit_record_table', () async {
      await call('whph_habit_records_set', {
        'habitId': habitId,
        'date': '2026-09-08',
        'status': 'complete',
        'count': 1,
      });
    });
    await expectCaptured('habit_time_record_table', () async {
      await call('whph_habit_time_records_add', {
        'habitId': habitId,
        'durationSeconds': 90,
        'occurredAt': '2026-09-08T09:00:00+03:00',
      });
    });
  });

  test('notes and tags family: tag, tag relationship, note, note tag', () async {
    late Map<String, dynamic> first;
    late Map<String, dynamic> second;
    await expectCaptured('tag_table', () async {
      first = await call('whph_tags_create', {'name': 'A', 'type': 'label'});
      second = await call('whph_tags_create', {'name': 'B', 'type': 'label'});
    });
    await expectCaptured('tag_tag_table', () async {
      await call('whph_tag_relationships_set', {
        'tagId': first['id'],
        'expectedRevision': first['revision'],
        'relatedTagIds': [second['id']],
      });
    });
    await expectCaptured('note_table', () async {
      await call('whph_notes_create', {
        'title': 'MCP note',
        'content': 'body',
        'tagIds': [first['id']]
      });
    });
    expect(await clockRows('note_tag_table'), greaterThan(0), reason: 'the note-tag link is captured too');
  });

  test('usage family: ignore rule and tag rule', () async {
    await expectCaptured('app_usage_ignore_rule_table', () async {
      await call('whph_usage_ignore_rules_create', {'pattern': 'ignored*'});
    });
    final tag = await call('whph_tags_create', {'name': 'Rule tag', 'type': 'label'});
    await expectCaptured('app_usage_tag_rule_table', () async {
      await call('whph_usage_tag_rules_create', {'pattern': 'work*', 'tagId': tag['id']});
    });
  });

  test('settings family: a public setting', () async {
    await expectCaptured('setting_table', () async {
      await call('whph_settings_update', {'key': 'themeMode', 'value': 'dark'});
    });
  });
}

RequestHandlerExtra _requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'mcp-write-capture',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );
