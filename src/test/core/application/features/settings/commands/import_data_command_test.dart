import 'dart:convert';
import 'dart:typed_data';

import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';

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

  setUp(() {
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
    );

    // Default mock setup
    when(mockCompressionService.validateHeader(argThat(anything))).thenReturn(true);
    when(mockCompressionService.validateChecksum(argThat(anything))).thenAnswer((_) async => true);
    when(contextAppUsageRepository.truncate()).thenAnswer((_) async {});
    when(contextNoteTagRepository.truncate()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });

  group('ImportDataCommandHandler Version Compatibility Tests', () {
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
