import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';

const _smokeTimeout = Duration(minutes: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'official clients exercise the production MCP catalog and isolated SQLite',
    () async {
      final supportDirectory = await Directory.systemTemp.createTemp('whph-mcp-task-14-');
      final transferDirectory = Directory(p.join(supportDirectory.path, 'transfer'));
      await transferDirectory.create();
      _installUnitTestPlatformChannels();

      AppDatabase.resetInstance();
      final container = await AppBootstrapService.initializeIsolatedForTesting(supportDirectory);
      final database = AppDatabase.instance();
      final backup = await container.resolve<Mediator>().send<ExportDataCommand, ExportDataCommandResponse>(
            ExportDataCommand(ExportDataFileOptions.backup),
          );
      await File(p.join(transferDirectory.path, 'task-14-import.whph')).writeAsBytes(backup.fileContent as List<int>);
      final accessService = container.resolve<IMcpAccessService>();
      final runtime = container.resolve<McpRuntimeService>();
      final fullGrant = await accessService.createGrant(
        clientName: 'Task 14 full client',
        scopes: McpScopes.all,
      );
      final readonlyGrant = await accessService.createGrant(
        clientName: 'Task 14 read-only client',
        scopes: const {
          McpScopes.tasksRead,
          McpScopes.habitsRead,
          McpScopes.notesRead,
          McpScopes.tagsRead,
          McpScopes.timersRead,
          McpScopes.usageRead,
          McpScopes.settingsRead,
          McpScopes.syncRead,
          McpScopes.overviewRead,
          McpScopes.appRead,
        },
      );

      try {
        final port = await _reserveLoopbackPort();
        await runtime.updatePreferences(McpServerPreferences(
          isEnabled: true,
          port: port,
          transferDirectory: transferDirectory.path,
        ));
        expect(runtime.state.isRunning, isTrue);
        final endpoint = runtime.state.endpoint;
        expect(endpoint, isNotNull);

        final catalog = await _runSmoke(
          endpoint: endpoint!,
          token: fullGrant.token,
          mode: 'catalog',
          supportDirectory: supportDirectory,
        );
        expect(catalog['modern'], containsPair('toolCount', 89));
        expect(catalog['legacy'], containsPair('toolCount', 89));
        expect(
          (catalog['modern'] as Map<String, dynamic>)['protocolVersion'],
          '2026-07-28',
        );

        final happy = await _runSmoke(
          endpoint: endpoint,
          token: fullGrant.token,
          mode: 'happy',
          supportDirectory: supportDirectory,
        );
        final scenario = happy['scenario'] as Map<String, dynamic>;
        await _expectDatabaseReadback(container, scenario);

        final pending = await container.resolve<IMcpOperationService>().listPending();
        final operation = pending.singleWhere(
          (item) => item.id == scenario['operationId'],
        );
        expect(operation.requiredScopes, contains(McpScopes.dataImport));
        final approved = await container.resolve<IMcpOperationService>().approve(operation.id);
        expect(approved.status, McpOperationStatus.succeeded);

        final disconnect = await _runSmoke(
          endpoint: endpoint,
          token: fullGrant.token,
          mode: 'disconnect',
          supportDirectory: supportDirectory,
        );
        expect(
          disconnect['disconnect'],
          containsPair('readbackCount', 1),
        );

        final readonly = await _runSmoke(
          endpoint: endpoint,
          token: readonlyGrant.token,
          mode: 'readonly',
          supportDirectory: supportDirectory,
        );
        expect(readonly['readonly'], containsPair('deniedWrite', true));

        await accessService.revokeGrant(fullGrant.grant.id);
        final revoked = await _runSmoke(
          endpoint: endpoint,
          token: fullGrant.token,
          mode: 'revoked',
          supportDirectory: supportDirectory,
        );
        expect(revoked['revoked'], containsPair('connectionRejected', true));

        final stateFiles =
            supportDirectory.listSync(recursive: true, followLinks: false).whereType<File>().toList(growable: false);
        expect(stateFiles, isNotEmpty);
        for (final file in stateFiles.where((item) => !item.path.contains('.db'))) {
          final bytes = await file.readAsBytes();
          expect(utf8.decode(bytes, allowMalformed: true), isNot(contains(fullGrant.token)));
        }

        await runtime.shutdown();
        await database.close();
        await _expectReopenedSqliteReadback(supportDirectory, scenario);
      } finally {
        await runtime.shutdown();
        await accessService.dispose();
        await database.close();
        AppDatabase.resetInstance();
        _clearUnitTestPlatformChannels();
        if (await supportDirectory.exists()) {
          await supportDirectory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _expectReopenedSqliteReadback(
  Directory supportDirectory,
  Map<String, dynamic> scenario,
) async {
  final databaseFile = File(p.join(supportDirectory.path, 'debug_$databaseName'));
  expect(await databaseFile.exists(), isTrue);
  final reopened = AppDatabase.withExecutor(NativeDatabase(databaseFile));
  try {
    final tasks = await reopened.select(reopened.taskTable).get();
    final habits = await reopened.select(reopened.habitTable).get();
    final notes = await reopened.select(reopened.noteTable).get();
    expect(tasks.where((item) => item.id == scenario['taskId']), hasLength(1));
    expect(tasks.where((item) => item.id == scenario['childTaskId']), hasLength(1));
    expect(habits.where((item) => item.id == scenario['goodHabitId']), hasLength(1));
    expect(habits.where((item) => item.id == scenario['badHabitId']), hasLength(1));
    expect(notes.where((item) => item.id == scenario['noteId']), hasLength(1));
  } finally {
    await reopened.close();
  }
}

void _installUnitTestPlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('me.ahmetcetinkaya.whph/window_management'),
    (_) async => null,
  );
}

void _clearUnitTestPlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('me.ahmetcetinkaya.whph/window_management'),
    null,
  );
}

Future<int> _reserveLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<Map<String, dynamic>> _runSmoke({
  required Uri endpoint,
  required String token,
  required String mode,
  required Directory supportDirectory,
}) async {
  final repositoryRoot = Directory(p.normalize(p.join(Directory.current.path, '..')));
  final smokeDirectory = Directory(p.join(repositoryRoot.path, 'scripts', 'mcp-smoke'));
  final resultFile = File(p.join(supportDirectory.path, 'smoke-$mode.json'));
  final process = await Process.start(
    'npm',
    ['--prefix', smokeDirectory.path, 'test'],
    workingDirectory: repositoryRoot.path,
    environment: {
      ...Platform.environment,
      'MCP_SMOKE_URL': endpoint.toString(),
      'MCP_SMOKE_TOKEN': token,
      'MCP_SMOKE_MODE': mode,
      'MCP_SMOKE_RESULT_PATH': resultFile.path,
    },
  );
  final stdoutFuture = utf8.decoder.bind(process.stdout).join();
  final stderrFuture = utf8.decoder.bind(process.stderr).join();
  int exitCode;
  try {
    exitCode = await process.exitCode.timeout(_smokeTimeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    throw TestFailure('MCP smoke mode $mode timed out');
  }
  final stdout = await stdoutFuture;
  final stderr = await stderrFuture;
  expect('$stdout$stderr', isNot(contains(token)));
  if (exitCode != 0) {
    throw TestFailure(
      'MCP smoke mode $mode exited $exitCode\nstdout:\n$stdout\nstderr:\n$stderr',
    );
  }
  expect(await resultFile.exists(), isTrue);
  return jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
}

Future<void> _expectDatabaseReadback(
  IContainer container,
  Map<String, dynamic> scenario,
) async {
  final task = await container.resolve<ITaskRepository>().getById(scenario['taskId'] as String);
  final child = await container.resolve<ITaskRepository>().getById(scenario['childTaskId'] as String);
  final goodHabit = await container.resolve<IHabitRepository>().getById(scenario['goodHabitId'] as String);
  final badHabit = await container.resolve<IHabitRepository>().getById(scenario['badHabitId'] as String);
  final note = await container.resolve<INoteRepository>().getById(scenario['noteId'] as String);

  expect(task?.isCompleted, isFalse);
  expect(child?.parentTaskId, task?.id);
  expect(goodHabit?.name, startsWith('MCP good habit'));
  expect(badHabit?.name, startsWith('MCP bad habit'));
  expect(note?.title, startsWith('MCP edited note'));
  expect(note?.content, contains('İstanbul 🧪'));
}
