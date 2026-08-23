import 'dart:convert';
import 'dart:typed_data';

import 'package:acore/acore.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/commands/normalize_task_orders_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/application/shared/services/compression_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

import 'import_data_command_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<IAppUsageRepository>(),
  MockSpec<IAppUsageTagRepository>(),
  MockSpec<IAppUsageTimeRecordRepository>(),
  MockSpec<IAppUsageTagRuleRepository>(),
  MockSpec<IHabitRepository>(),
  MockSpec<IHabitRecordRepository>(),
  MockSpec<IHabitTagsRepository>(),
  MockSpec<ITagRepository>(),
  MockSpec<ITagTagRepository>(),
  MockSpec<ITaskRepository>(),
  MockSpec<ITaskTagRepository>(),
  MockSpec<ITaskTimeRecordRepository>(),
  MockSpec<ISettingRepository>(),
  MockSpec<ISyncDeviceRepository>(),
  MockSpec<IAppUsageIgnoreRuleRepository>(),
  MockSpec<INoteRepository>(),
  MockSpec<INoteTagRepository>(),
  MockSpec<IImportDataMigrationService>(),
  MockSpec<ICompressionService>(),
])
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

void main() {
  late ImportDataCommandHandler handler;
  late MockIAppUsageRepository contextAppUsageRepository;
  late MockIAppUsageTagRepository contextAppUsageTagRepository;
  late MockIAppUsageTimeRecordRepository contextAppUsageTimeRecordRepository;
  late MockIAppUsageTagRuleRepository contextAppUsageTagRuleRepository;
  late MockIHabitRepository contextHabitRepository;
  late MockIHabitRecordRepository contextHabitRecordRepository;
  late MockIHabitTagsRepository contextHabitTagsRepository;
  late MockITagRepository contextTagRepository;
  late MockITagTagRepository contextTagTagRepository;
  late MockITaskRepository contextTaskRepository;
  late MockITaskTagRepository contextTaskTagRepository;
  late MockITaskTimeRecordRepository contextTaskTimeRecordRepository;
  late MockISettingRepository contextSettingRepository;
  late MockISyncDeviceRepository contextSyncDeviceRepository;
  late MockIAppUsageIgnoreRuleRepository contextAppUsageIgnoreRuleRepository;
  late MockINoteRepository contextNoteRepository;
  late MockINoteTagRepository contextNoteTagRepository;
  late MockIImportDataMigrationService mockMigrationService;
  late MockICompressionService mockCompressionService;
  late Mediator mediator;
  late List<Habit> storedHabits;
  late List<Task> storedTasks;
  late List<Note> storedNotes;

  setUp(() {
    initializeJsonMapper();
    // Setup in-memory database to bypass DI resolution of IApplicationDirectoryService
    // and avoid "KiwiError: Failed to resolve IApplicationDirectoryService"
    AppDatabase.setInstanceForTesting(AppDatabase.forTesting());

    contextAppUsageRepository = MockIAppUsageRepository();
    contextAppUsageTagRepository = MockIAppUsageTagRepository();
    contextAppUsageTimeRecordRepository = MockIAppUsageTimeRecordRepository();
    contextAppUsageTagRuleRepository = MockIAppUsageTagRuleRepository();
    contextHabitRepository = MockIHabitRepository();
    contextHabitRecordRepository = MockIHabitRecordRepository();
    contextHabitTagsRepository = MockIHabitTagsRepository();
    contextTagRepository = MockITagRepository();
    contextTagTagRepository = MockITagTagRepository();
    contextTaskRepository = MockITaskRepository();
    contextTaskTagRepository = MockITaskTagRepository();
    contextTaskTimeRecordRepository = MockITaskTimeRecordRepository();
    contextSettingRepository = MockISettingRepository();
    contextSyncDeviceRepository = MockISyncDeviceRepository();
    contextAppUsageIgnoreRuleRepository = MockIAppUsageIgnoreRuleRepository();
    contextNoteRepository = MockINoteRepository();
    contextNoteTagRepository = MockINoteTagRepository();
    mockMigrationService = MockIImportDataMigrationService();
    mockCompressionService = MockICompressionService();
    storedHabits = [];
    storedTasks = [];
    storedNotes = [];
    mediator = Mediator(Pipeline())
      ..registerHandler<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
        () => NormalizeHabitOrdersCommandHandler(contextHabitRepository),
      )
      ..registerHandler<NormalizeTaskOrdersCommand, NormalizeTaskOrdersResponse, NormalizeTaskOrdersCommandHandler>(
        () => NormalizeTaskOrdersCommandHandler(contextTaskRepository),
      )
      ..registerHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse, NormalizeNoteOrdersCommandHandler>(
        () => NormalizeNoteOrdersCommandHandler(contextNoteRepository),
      );

    handler = ImportDataCommandHandler(
      appUsageRepository: contextAppUsageRepository,
      appUsageTagRepository: contextAppUsageTagRepository,
      appUsageTimeRecordRepository: contextAppUsageTimeRecordRepository,
      appUsageTagRuleRepository: contextAppUsageTagRuleRepository,
      habitRepository: contextHabitRepository,
      habitRecordRepository: contextHabitRecordRepository,
      habitTagRepository: contextHabitTagsRepository,
      tagRepository: contextTagRepository,
      tagTagRepository: contextTagTagRepository,
      taskRepository: contextTaskRepository,
      taskTagRepository: contextTaskTagRepository,
      taskTimeRecordRepository: contextTaskTimeRecordRepository,
      settingRepository: contextSettingRepository,
      syncDeviceRepository: contextSyncDeviceRepository,
      appUsageIgnoreRuleRepository: contextAppUsageIgnoreRuleRepository,
      noteRepository: contextNoteRepository,
      noteTagRepository: contextNoteTagRepository,
      migrationService: mockMigrationService,
      compressionService: mockCompressionService,
      mediator: mediator,
    );

    // Default mock setup
    when(mockCompressionService.validateHeader(argThat(anything))).thenReturn(true);
    when(mockCompressionService.validateChecksum(argThat(anything))).thenAnswer((_) async => true);
    when(contextAppUsageRepository.truncate()).thenAnswer((_) async {});
    when(contextNoteTagRepository.truncate()).thenAnswer((_) async {});
    when(contextHabitRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => storedHabits);
    when(contextTaskRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => storedTasks);
    when(contextHabitRepository.add(any)).thenAnswer((invocation) async {
      storedHabits.add(invocation.positionalArguments.single as Habit);
    });
    when(contextHabitRepository.updateMultiple(any)).thenAnswer((_) async {});
    when(contextTaskRepository.add(any)).thenAnswer((invocation) async {
      storedTasks.add(invocation.positionalArguments.single as Task);
    });
    when(contextTaskRepository.updateMultiple(any)).thenAnswer((_) async {});
    when(contextNoteRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => storedNotes);
    when(contextNoteRepository.add(any)).thenAnswer((invocation) async {
      storedNotes.add(invocation.positionalArguments.single as Note);
    });
    when(contextNoteRepository.updateMultiple(any)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });

  group('ImportDataCommandHandler Version Compatibility Tests', () {
    test('imports legacy numeric ranks from a real compressed backup', () async {
      final compressionService = CompressionService();
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'habits': [
          _habitJson('habit-3', 3.0),
          _habitJson('habit-1', 1.0),
          _habitJson('habit-2', 2.0),
        ],
        'tasks': [
          _taskJson('task-root', 1.0),
          _taskJson('task-child', 2.0, parentTaskId: 'task-root'),
        ],
        'notes': [_noteJson('note-1', 1.0)],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      final numericOrder = storedHabits.toList()..sort((a, b) => a.order.compareTo(b.order));
      expect(numericOrder.map((habit) => habit.name), orderedEquals(['habit-1', 'habit-2', 'habit-3']));
      expect(numericOrder.map((habit) => habit.order).toSet(), hasLength(3));
      expect(numericOrder.map((habit) => OrderRank.needsNormalization([habit.order])), everyElement(isFalse));
      expect(storedTasks, hasLength(2));
    });

    test('preserves canonical rank strings while importing', () async {
      final compressionService = CompressionService();
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'habits': [_habitJson('habit-current', 'V')],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      final importedHabit = verify(contextHabitRepository.add(captureAny)).captured.single as Habit;
      expect(importedHabit.order, 'V');
    });

    test('normalizes legacy rank collisions without dropping habits', () async {
      final compressionService = CompressionService();
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'habits': [
          _habitJson('habit-a', 0.0),
          _habitJson('habit-b', 0.0),
          _habitJson('habit-c', 0.0),
        ],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      expect(storedHabits, hasLength(3));
      expect(storedHabits.map((habit) => habit.order).toSet(), hasLength(3));
      expect(storedHabits.map((habit) => OrderRank.needsNormalization([habit.order])), everyElement(isFalse));
    });

    test('normalizes legacy rank collisions in imported notes without dropping any', () async {
      // Notes were excluded from the post-import normalization pass, so
      // duplicate ranks from a legacy or malformed backup survived import
      // and left the notes' relative order undefined.
      final compressionService = CompressionService();
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'notes': [
          _noteJson('note-a', 0.0),
          _noteJson('note-b', 0.0),
          _noteJson('note-c', 0.0),
        ],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      expect(storedNotes, hasLength(3));
      expect(storedNotes.map((note) => note.order).toSet(), hasLength(3));
      expect(storedNotes.map((note) => OrderRank.needsNormalization([note.order])), everyElement(isFalse));
    });

    test('normalizes imported tasks per parent scope in a single fetch and single batch update', () async {
      // Task normalization is grouped by parentTaskId and applied as one
      // fetch + one batch update, rather than one mediator round-trip and one
      // repository fetch/update pair per distinct parent scope. Each of two
      // sibling groups under different parents (plus one root group) starts
      // with a distinct, already-ordered legacy rank, so a correct per-parent
      // normalization must preserve each group's own relative order —
      // proving scoping actually happened, not just "some" normalization.
      final compressionService = CompressionService();
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'tasks': [
          _taskJson('root-a', 1.0),
          _taskJson('root-b', 2.0),
          _taskJson('child-x1', 1.0, parentTaskId: 'parent-x'),
          _taskJson('child-x2', 2.0, parentTaskId: 'parent-x'),
          _taskJson('child-y1', 1.0, parentTaskId: 'parent-y'),
          _taskJson('child-y2', 2.0, parentTaskId: 'parent-y'),
        ],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      expect(storedTasks, hasLength(6));
      expect(storedTasks.map((task) => OrderRank.needsNormalization([task.order])), everyElement(isFalse));

      final byId = {for (final task in storedTasks) task.id: task};
      final rootOrders = storedTasks.where((t) => t.parentTaskId == null).map((t) => t.order).toSet();
      final parentXOrders = storedTasks.where((t) => t.parentTaskId == 'parent-x').map((t) => t.order).toSet();
      final parentYOrders = storedTasks.where((t) => t.parentTaskId == 'parent-y').map((t) => t.order).toSet();

      expect(rootOrders, hasLength(2), reason: 'root siblings must get distinct ranks');
      expect(parentXOrders, hasLength(2), reason: 'parent-x siblings must get distinct ranks');
      expect(parentYOrders, hasLength(2), reason: 'parent-y siblings must get distinct ranks');

      // Each partition's rank ordering must follow its own pre-import
      // relative order, proving the grouping is genuinely per-parent rather
      // than one flattened global sequence that could interleave partitions.
      expect(byId['child-x1']!.order.compareTo(byId['child-x2']!.order), lessThan(0));
      expect(byId['child-y1']!.order.compareTo(byId['child-y2']!.order), lessThan(0));
      expect(byId['root-a']!.order.compareTo(byId['root-b']!.order), lessThan(0));

      // Consolidated into one fetch and one batch update, not N pairs (one
      // per distinct parent scope).
      verify(contextTaskRepository.getAll(
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).called(1);
      verify(contextTaskRepository.updateMultiple(any)).called(1);
    });

    test('replaces malformed, absent, and wrong-type entity ranks with the initial rank', () async {
      final compressionService = CompressionService();
      final missingTaskOrder = _taskJson('task-missing', 'U')..remove('order');
      String? persistedHabitOrder;
      String? persistedTaskOrder;
      String? persistedNoteOrder;
      final backupData = await compressionService.createWhphFile(jsonEncode({
        'appInfo': {'version': AppInfo.version},
        'habits': [_habitJson('habit-malformed', 'not canonical!')],
        'tasks': [missingTaskOrder],
        'notes': [_noteJson('note-wrong-type', true)],
      }));

      when(mockCompressionService.validateHeader(backupData)).thenReturn(true);
      when(mockCompressionService.validateChecksum(backupData)).thenAnswer((_) async => true);
      when(mockCompressionService.extractFromWhphFile(backupData))
          .thenAnswer((_) => compressionService.extractFromWhphFile(backupData));
      when(contextHabitRepository.add(any)).thenAnswer((invocation) async {
        final habit = invocation.positionalArguments.single as Habit;
        persistedHabitOrder = habit.order;
        storedHabits.add(habit);
      });
      when(contextTaskRepository.add(any)).thenAnswer((invocation) async {
        final task = invocation.positionalArguments.single as Task;
        persistedTaskOrder = task.order;
        storedTasks.add(task);
      });
      when(contextNoteRepository.add(any)).thenAnswer((invocation) async {
        final note = invocation.positionalArguments.single as Note;
        persistedNoteOrder = note.order;
        storedNotes.add(note);
      });

      await handler.call(ImportDataCommand(backupData, ImportStrategy.replace));

      expect(persistedHabitOrder, OrderRank.initialRank);
      expect(persistedTaskOrder, OrderRank.initialRank);
      expect(persistedNoteOrder, OrderRank.initialRank);
    });
    test('should allow import when older version provided and no migration needed (Issue #219)', () async {
      // Arrange
      // "0.20.3" is less than current version (e.g., "0.20.4")
      // Assuming AppInfo.version is "0.20.4" based on file check
      const olderVersion = "0.20.3";
      final backupData = Uint8List(0); // Dummy data, we mock the extraction

      when(mockCompressionService.extractFromWhphFile(any)).thenAnswer((_) async {
        return jsonEncode({
          'appInfo': {'version': olderVersion},
          'tasks': []
        });
      });

      // Migration not needed
      when(mockMigrationService.isMigrationNeeded(olderVersion)).thenReturn(false);

      // Act
      final command = ImportDataCommand(backupData, ImportStrategy.replace);
      final response = await handler.call(command);

      // Assert
      expect(response, isA<ImportDataCommandResponse>());
      verify(mockMigrationService.isMigrationNeeded(olderVersion)).called(1);
      // Ensure no migration data command called
      verifyNever(mockMigrationService.migrateData(any, any));
    });

    test('should throw error when newer version provided', () async {
      // Arrange
      const newerVersion = "99.99.99";
      final backupData = Uint8List(0);

      when(mockCompressionService.extractFromWhphFile(any)).thenAnswer((_) async {
        return jsonEncode({
          'appInfo': {'version': newerVersion},
          'tasks': []
        });
      });

      // Migration not needed (it's newer)
      when(mockMigrationService.isMigrationNeeded(newerVersion)).thenReturn(false);

      // Act & Assert
      final command = ImportDataCommand(backupData, ImportStrategy.replace);

      expect(
          () => handler.call(command),
          throwsA(predicate((e) =>
              e is BusinessException &&
              e.errorCode == SettingsTranslationKeys.versionMismatchError &&
              e.message.contains('Newer version'))));
    });

    test('should allow import when version is same as current', () async {
      // Arrange
      final currentVersion = AppInfo.version;
      final backupData = Uint8List(0);

      when(mockCompressionService.extractFromWhphFile(any)).thenAnswer((_) async {
        return jsonEncode({
          'appInfo': {'version': currentVersion},
          'tasks': []
        });
      });

      when(mockMigrationService.isMigrationNeeded(currentVersion)).thenReturn(false);

      // Act
      final command = ImportDataCommand(backupData, ImportStrategy.replace);
      final response = await handler.call(command);

      // Assert
      expect(response, isA<ImportDataCommandResponse>());
    });

    test('should perform migration when older version provided and migration IS needed', () async {
      // Arrange
      const oldVersion = "0.15.0";
      final backupData = Uint8List(0);

      when(mockCompressionService.extractFromWhphFile(any)).thenAnswer((_) async {
        return jsonEncode({
          'appInfo': {'version': oldVersion},
          'tasks': []
        });
      });

      when(mockMigrationService.isMigrationNeeded(oldVersion)).thenReturn(true);
      when(mockMigrationService.migrateData(any, oldVersion)).thenAnswer((_) async {
        return {
          'appInfo': {'version': AppInfo.version}, // Simulating migrated data
          'tasks': []
        };
      });

      // Act
      final command = ImportDataCommand(backupData, ImportStrategy.replace);
      final response = await handler.call(command);

      // Assert
      expect(response, isA<ImportDataCommandResponse>());
      verify(mockMigrationService.migrateData(any, oldVersion)).called(1);
    });

    test('should throw BusinessException with correct error code when version format is invalid', () async {
      // Arrange
      final backupData = Uint8List(0);

      when(mockCompressionService.extractFromWhphFile(any)).thenAnswer((_) async {
        return jsonEncode({
          'appInfo': {'version': 'invalid.version.format'},
          'tasks': []
        });
      });

      // Migration not needed (invalid version will be caught before this check)
      when(mockMigrationService.isMigrationNeeded(any)).thenReturn(false);

      // Act & Assert
      final command = ImportDataCommand(backupData, ImportStrategy.replace);
      expect(
          () => handler.call(command),
          throwsA(predicate(
              (e) => e is BusinessException && e.errorCode == SettingsTranslationKeys.backupInvalidFormatError)));
    });

    test('should throw BusinessException with error when backup is corrupted', () async {
      // Arrange
      final backupData = Uint8List(0);

      when(mockCompressionService.validateChecksum(any)).thenAnswer((_) async => false);

      // Act & Assert
      final command = ImportDataCommand(backupData, ImportStrategy.replace);
      expect(
          () => handler.call(command),
          throwsA(
              predicate((e) => e is BusinessException && e.errorCode == SettingsTranslationKeys.backupCorruptedError)));
    });
  });
}

Map<String, dynamic> _habitJson(String id, Object order) {
  final habit = Habit(
    id: id,
    createdDate: DateTime.utc(2026),
    name: id,
    description: '',
  );
  return {...jsonDecode(JsonMapper.serialize(habit)) as Map<String, dynamic>, 'order': order};
}

Map<String, dynamic> _taskJson(String id, Object order, {String? parentTaskId, String? createdDate}) {
  final task = Task(
    id: id,
    createdDate: createdDate != null ? DateTime.parse(createdDate) : DateTime.utc(2026),
    title: id,
    parentTaskId: parentTaskId,
  );
  return {...jsonDecode(JsonMapper.serialize(task)) as Map<String, dynamic>, 'order': order};
}

Map<String, dynamic> _noteJson(String id, Object order) {
  final note = Note(id: id, createdDate: DateTime.utc(2026), title: id);
  return {...jsonDecode(JsonMapper.serialize(note)) as Map<String, dynamic>, 'order': order};
}
