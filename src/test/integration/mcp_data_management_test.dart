import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/settings/settings_registration.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/infrastructure/persistence/persistence_container.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_data_transfer_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_transfer_file_store.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph/presentation/mcp/tools/data_transfer_tools.dart';

void main() {
  late Directory applicationDirectory;
  late Directory transferDirectory;
  late McpAccessService accessService;
  late McpOperationStore operationStore;
  late McpOperationService operationService;
  late McpTransferFileStore transferStore;
  late McpIssuedGrant grant;
  var now = DateTime.utc(2026, 9, 8, 12);

  setUp(() async {
    applicationDirectory =
        await Directory.systemTemp.createTemp('whph_mcp_data_');
    transferDirectory =
        Directory(p.join(applicationDirectory.path, 'transfer'));
    await transferDirectory.create();
    final directoryService = _TestDirectoryService(applicationDirectory);
    accessService = McpAccessService(
      store: McpAccessStore(applicationDirectoryService: directoryService),
      now: () => now,
    );
    await accessService.setPreferences(McpServerPreferences(
      isEnabled: true,
      port: 44041,
      transferDirectory: transferDirectory.path,
    ));
    grant = await accessService.createGrant(
      clientName: 'Data manager',
      scopes: const {
        McpScopes.dataImport,
        McpScopes.dataExport,
        McpScopes.tasksWrite,
      },
    );
    operationStore = McpOperationStore(
      applicationDirectoryService: directoryService,
    );
    operationService = McpOperationService(
      store: operationStore,
      accessService: accessService,
      now: () => now,
    );
    transferStore = McpTransferFileStore(
      applicationDirectoryService: directoryService,
      accessService: accessService,
      now: () => now,
    );
  });

  tearDown(() async {
    await accessService.dispose();
    if (await applicationDirectory.exists()) {
      await applicationDirectory.delete(recursive: true);
    }
  });

  test('local approval is one-use and remains bound to grant scopes', () async {
    var executions = 0;
    final operation = await operationService.prepare(
      clientGrantId: grant.grant.id,
      type: McpOperationType.dataImport,
      requiredScopes: const {McpScopes.dataImport, McpScopes.tasksWrite},
      requestHash: 'a' * 64,
      summary: 'Merge one task backup',
      execute: () async {
        executions++;
        return McpOperationResult({'imported': 1});
      },
    );

    final approved = await operationService.approve(operation.id);

    expect(approved.status, McpOperationStatus.succeeded);
    expect(approved.result?.value, {'imported': 1});
    expect(executions, 1);
    expect(
      await operationService.getForClient(
        operationId: operation.id,
        clientGrantId: 'another-grant',
        currentScopes: grant.grant.scopes,
      ),
      isNull,
    );
    expect(
      await operationService.getForClient(
        operationId: operation.id,
        clientGrantId: grant.grant.id,
        currentScopes: const {McpScopes.dataImport},
      ),
      isNull,
    );
    await expectLater(
      operationService.approve(operation.id),
      throwsStateError,
    );
    expect(executions, 1);
  });

  test('revoked approval is cancelled without executing', () async {
    var executed = false;
    final operation = await operationService.prepare(
      clientGrantId: grant.grant.id,
      type: McpOperationType.dataImport,
      requiredScopes: const {McpScopes.dataImport},
      requestHash: 'b' * 64,
      summary: 'Replace local data',
      execute: () async {
        executed = true;
        return McpOperationResult(const {});
      },
    );
    await accessService.revokeGrant(grant.grant.id);

    final result = await operationService.approve(operation.id);

    expect(result.status, McpOperationStatus.cancelled);
    expect(result.failure?.code, 'permission_denied');
    expect(executed, isFalse);
  });

  test('reject and expiry never execute and restart cannot resurrect work',
      () async {
    var executions = 0;
    Future<McpOperation> prepare(String hash) => operationService.prepare(
          clientGrantId: grant.grant.id,
          type: McpOperationType.dataImport,
          requiredScopes: const {McpScopes.dataImport},
          requestHash: hash * 64,
          summary: 'Pending import',
          execute: () async {
            executions++;
            return McpOperationResult(const {});
          },
        );

    final rejected = await prepare('c');
    expect(
      (await operationService.reject(rejected.id)).status,
      McpOperationStatus.rejected,
    );
    final expiring = await prepare('d');
    now = now.add(const Duration(minutes: 6));
    expect(
      (await operationService.getForClient(
        operationId: expiring.id,
        clientGrantId: grant.grant.id,
        currentScopes: grant.grant.scopes,
      ))
          ?.status,
      McpOperationStatus.expired,
    );
    final persisted = await prepare('e');
    final restarted = McpOperationService(
      store: operationStore,
      accessService: accessService,
      now: () => now,
    );
    expect(
      (await restarted.getForClient(
        operationId: persisted.id,
        clientGrantId: grant.grant.id,
        currentScopes: grant.grant.scopes,
      ))
          ?.status,
      McpOperationStatus.expired,
    );
    expect(executions, 0);
  });

  test('export artifacts are opaque, caller-bound, and chunk bounded',
      () async {
    final content = List<int>.generate(
      mcpMaximumArtifactChunkBytes + 7,
      (index) => index % 251,
    );
    final artifact = await transferStore.storeExport(
      clientGrantId: grant.grant.id,
      fileName: 'backup.whph',
      fileExtension: 'whph',
      content: content,
    );

    final first = await transferStore.readArtifactChunk(
      clientGrantId: grant.grant.id,
      artifactId: artifact.id,
      offset: 0,
    );
    final second = await transferStore.readArtifactChunk(
      clientGrantId: grant.grant.id,
      artifactId: artifact.id,
      offset: first!.nextOffset!,
    );

    expect(artifact.id, isNot(contains('backup')));
    expect(first.bytes, hasLength(mcpMaximumArtifactChunkBytes));
    expect(second?.bytes, hasLength(7));
    final restartedStore = McpTransferFileStore(
      applicationDirectoryService: _TestDirectoryService(applicationDirectory),
      accessService: accessService,
      now: () => now,
    );
    expect(
      (await restartedStore.readArtifactChunk(
        clientGrantId: grant.grant.id,
        artifactId: artifact.id,
        offset: 0,
      ))
          ?.bytes,
      hasLength(mcpMaximumArtifactChunkBytes),
    );
    expect(
      await transferStore.readArtifactChunk(
        clientGrantId: 'another-grant',
        artifactId: artifact.id,
        offset: 0,
      ),
      isNull,
    );
  });

  test('import staging rejects traversal and symbolic links', () async {
    await expectLater(
      transferStore.stageImport(
        clientGrantId: grant.grant.id,
        sourceName: '../outside.whph',
      ),
      throwsArgumentError,
    );
    final outside = File(p.join(applicationDirectory.path, 'outside.whph'));
    await outside.writeAsBytes([1, 2, 3]);
    final link = Link(p.join(transferDirectory.path, 'linked.whph'));
    await link.create(outside.path);

    await expectLater(
      transferStore.stageImport(
        clientGrantId: grant.grant.id,
        sourceName: 'linked.whph',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('import staging rejects inputs over 100 MiB before copying', () async {
    final oversized = File(p.join(transferDirectory.path, 'oversized.whph'));
    final handle = await oversized.open(mode: FileMode.write);
    await handle.truncate(mcpMaximumTransferInputBytes + 1);
    await handle.close();

    await expectLater(
      transferStore.stageImport(
        clientGrantId: grant.grant.id,
        sourceName: 'oversized.whph',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await Directory(p.join(applicationDirectory.path, 'mcp', 'staging'))
          .exists(),
      isFalse,
    );
  });

  test('import tool schema has no agent-controlled approval field', () {
    final tool = buildDataTransferTools(
      transferService: _UnusedTransferService(),
      operationService: operationService,
      requestContext: _UnusedRequestContext(),
    ).singleWhere((item) => item.name == 'whph_data_import_prepare');
    final properties =
        tool.inputSchema.toJson()['properties'] as Map<String, dynamic>;

    expect(properties.keys, {'sourceName', 'strategy'});
    expect(properties, isNot(contains('approved')));
    expect(tool.inputSchema.toJson()['additionalProperties'], isFalse);
  });

  test('staged import detects byte changes before commit', () async {
    final source = File(p.join(transferDirectory.path, 'input.whph'));
    await source.writeAsBytes(List<int>.filled(64, 9));
    final staged = await transferStore.stageImport(
      clientGrantId: grant.grant.id,
      sourceName: 'input.whph',
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', staged.path]);
    }
    await File(staged.path).writeAsBytes([1, 2, 3]);

    expect(await transferStore.verifyStaged(staged), isFalse);
  });

  test('real SQLite WHPH round-trip includes task statuses and habit time',
      () async {
    initializeJsonMapper();
    AppDatabase.resetInstance();
    AppDatabase.isTestMode = true;
    AppDatabase.testDirectory = applicationDirectory;
    final container = Container();
    container.registerSingleton<IApplicationDirectoryService>(
      (_) => _TestDirectoryService(applicationDirectory),
    );
    registerPersistence(container);
    final database = AppDatabase.instance(container);
    addTearDown(() async {
      await database.close();
      AppDatabase.resetInstance();
    });
    final mediator = Mediator(Pipeline())
      ..registerHandler<NormalizeHabitOrdersCommand,
          NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
        () => NormalizeHabitOrdersCommandHandler(
          container.resolve<IHabitRepository>(),
        ),
      )
      ..registerHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse,
          NormalizeNoteOrdersCommandHandler>(
        () => NormalizeNoteOrdersCommandHandler(
          container.resolve<INoteRepository>(),
        ),
      );
    registerSettingsFeature(
      container,
      mediator,
      container.resolve<ISettingRepository>(),
      container.resolve<IAppUsageIgnoreRuleRepository>(),
      container.resolve<IAppUsageRepository>(),
      container.resolve<IAppUsageTagRepository>(),
      container.resolve<IAppUsageTagRuleRepository>(),
      container.resolve<IAppUsageTimeRecordRepository>(),
      container.resolve<IHabitRecordRepository>(),
      container.resolve<IHabitRepository>(),
      container.resolve<IHabitTagsRepository>(),
      container.resolve<ISyncDeviceRepository>(),
      container.resolve<ITagRepository>(),
      container.resolve<ITagTagRepository>(),
      container.resolve<ITaskRepository>(),
      container.resolve<ITaskTagRepository>(),
      container.resolve<ITaskTimeRecordRepository>(),
      container.resolve<INoteRepository>(),
      container.resolve<INoteTagRepository>(),
    );
    final habits = container.resolve<IHabitRepository>();
    final habitTimes = container.resolve<IHabitTimeRecordRepository>();
    final taskStatuses = container.resolve<ITaskStatusRepository>();
    final createdAt = DateTime.utc(2026, 9, 8, 10);
    await habits.add(Habit(
      id: 'habit-roundtrip',
      createdDate: createdAt,
      name: 'Round trip habit',
      description: 'SQLite evidence',
    ));
    await habitTimes.add(HabitTimeRecord(
      id: 'habit-time-roundtrip',
      habitId: 'habit-roundtrip',
      duration: 321,
      occurredAt: createdAt,
      createdDate: createdAt,
    ));
    await taskStatuses.add(TaskStatus(
      id: 'status-roundtrip',
      createdDate: createdAt,
      name: 'Round trip status',
      order: 'V',
    ));

    final fullGrant = await accessService.createGrant(
      clientName: 'Full data manager',
      scopes: McpScopes.all,
    );
    var reloadCount = 0;
    final timerSessions = _TrackingTimerSessions();
    final dataTransfers = McpDataTransferService(
      mediator: mediator,
      compressionService: container.resolve<ICompressionService>(),
      timerSessionService: timerSessions,
      operationService: operationService,
      fileStore: transferStore,
      database: database,
      reloadApplicationState: () async => reloadCount++,
    );
    final exported = await dataTransfers.exportData(
      clientGrantId: fullGrant.grant.id,
      format: McpDataExportFormat.whph,
    );
    final snapshot = await database.restoreBarrier.runExclusive(
      database.createRestoreSnapshot,
    );
    expect(await snapshot.length(), greaterThan(16));
    expect(
      String.fromCharCodes(
          await snapshot.openRead(0, 16).expand((e) => e).toList()),
      'SQLite format 3\u0000',
    );
    final snapshotRows = await Process.run('sqlite3', [
      snapshot.path,
      'SELECT (SELECT COUNT(*) FROM habit_time_record_table), '
          '(SELECT COUNT(*) FROM task_status_table);',
    ]);
    expect(snapshotRows.exitCode, 0);
    expect((snapshotRows.stdout as String).trim(), '1|1');

    final artifactChunk = await dataTransfers.readArtifactChunk(
      clientGrantId: fullGrant.grant.id,
      artifactId: exported.id,
      offset: 0,
    );
    await File(p.join(transferDirectory.path, 'roundtrip.whph'))
        .writeAsBytes(artifactChunk!.bytes);
    await habitTimes.truncate();
    await taskStatuses.truncate();
    await habits.truncate();
    await expectLater(
      dataTransfers.prepareImport(
        clientGrantId: fullGrant.grant.id,
        currentScopes: const {McpScopes.dataImport},
        sourceName: 'roundtrip.whph',
        strategy: McpDataImportStrategy.merge,
      ),
      throwsA(predicate<McpDataTransferException>(
          (error) => error.failure == McpDataTransferFailure.permissionDenied)),
    );
    final changedAfterApproval = await dataTransfers.prepareImport(
      clientGrantId: fullGrant.grant.id,
      currentScopes: fullGrant.grant.scopes,
      sourceName: 'roundtrip.whph',
      strategy: McpDataImportStrategy.merge,
    );
    final stagedFile = (await Directory(
      p.join(applicationDirectory.path, 'mcp', 'staging'),
    ).list().where((entry) => entry is File).single) as File;
    if (!Platform.isWindows)
      await Process.run('chmod', ['600', stagedFile.path]);
    await stagedFile.writeAsBytes([1, 2, 3]);
    expect(
      (await operationService.approve(changedAfterApproval.id)).status,
      McpOperationStatus.failed,
    );
    final prepared = await dataTransfers.prepareImport(
      clientGrantId: fullGrant.grant.id,
      currentScopes: fullGrant.grant.scopes,
      sourceName: 'roundtrip.whph',
      strategy: McpDataImportStrategy.merge,
    );
    expect(prepared.status, McpOperationStatus.pendingApproval);
    final approved = await operationService.approve(prepared.id);

    expect(approved.status, McpOperationStatus.succeeded);
    expect(timerSessions.stoppedSessionIds, const ['active-timer']);
    expect(reloadCount, 1);
    expect((await habitTimes.getById('habit-time-roundtrip'))?.duration, 321);
    expect(
      (await taskStatuses.getById('status-roundtrip'))?.name,
      'Round trip status',
    );
  });
}

final class _TestDirectoryService implements IApplicationDirectoryService {
  const _TestDirectoryService(this.directory);

  final Directory directory;

  @override
  Future<Directory> getApplicationDirectory() async => directory;
}

final class _UnusedTransferService implements IMcpDataTransferService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedRequestContext implements IMcpRequestContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TrackingTimerSessions extends Fake
    implements ITimerSessionService {
  static const _state = TimerSessionState(
    sessionId: 'active-timer',
    owner: TimerSessionOwner.task('task'),
    settings: TimerSessionSettings(
      mode: TimerSessionMode.normal,
      workDuration: Duration(minutes: 25),
      breakDuration: Duration(minutes: 5),
      longBreakDuration: Duration(minutes: 15),
      sessionsBeforeLongBreak: 4,
    ),
    isRunning: true,
    isWorking: true,
    isAlarmPlaying: false,
    isLongBreak: false,
    remainingTime: Duration(minutes: 20),
    elapsedTime: Duration(minutes: 5),
    sessionTotalElapsed: Duration(minutes: 5),
    currentWorkSessionElapsed: Duration(minutes: 5),
    completedSessions: 0,
  );

  List<String> stoppedSessionIds = const [];

  @override
  List<TimerSessionState> list() => const [_state];

  @override
  Future<TimerSessionState> stop(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  }) async {
    stoppedSessionIds = List.unmodifiable([...stoppedSessionIds, sessionId]);
    await beforeCommit?.call();
    return _state;
  }
}
