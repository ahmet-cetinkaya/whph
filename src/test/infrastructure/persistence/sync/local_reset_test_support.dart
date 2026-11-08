// Real app services over a device's Drift DB for the T21 import, reset and
// demo tests: the replace-import handler and the demo data service, both
// wired to the device's membership service.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/demo/services/demo_data_service.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/core/application/features/tasks/commands/normalize_task_orders_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_device_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_status_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../shared/features/sync/sync_security_test_support.dart';

/// Hands the handler a prepared JSON document instead of a `.whph` archive.
class _JsonCompressionService implements ICompressionService {
  final String json;

  _JsonCompressionService(this.json);

  @override
  bool validateHeader(Uint8List data) => true;

  @override
  Future<bool> validateChecksum(Uint8List whphData) async => true;

  @override
  Future<String> extractFromWhphFile(Uint8List whphData) async => json;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoMigration implements IImportDataMigrationService {
  @override
  bool isMigrationNeeded(String sourceVersion) => false;

  @override
  List<String> getAvailableMigrationVersions() => const [];

  @override
  Future<Map<String, dynamic>> migrateData(
          Map<String, dynamic> data, String sourceVersion) async =>
      data;
}

/// The export document of a note list, as `ExportDataCommand` writes it.
String exportOfNotes(Map<String, String> titlesById) => jsonEncode({
      'appInfo': {'version': AppInfo.version},
      'notes': [
        for (final entry in titlesById.entries)
          jsonDecode(JsonMapper.serialize(Note(
              id: entry.key,
              createdDate: DateTime.utc(2026),
              title: entry.value,
              order: entry.key)))
      ],
    });

extension LocalResetServices on SecurityDevice {
  AppDatabase get appDatabase => database.db;

  /// Pass [membershipWired] false for a handler without sync (plain path).
  ImportDataCommandHandler importHandler(String exportJson,
      {bool membershipWired = true}) {
    final db = appDatabase;
    final noteRepository = DriftNoteRepository.withDatabase(db);
    final habitRepository = DriftHabitRepository.withDatabase(db);
    final taskRepository = DriftTaskRepository.withDatabase(db);
    final mediator = Mediator(Pipeline())
      ..registerHandler<NormalizeHabitOrdersCommand,
              NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
          () => NormalizeHabitOrdersCommandHandler(habitRepository))
      ..registerHandler<NormalizeTaskOrdersCommand, NormalizeTaskOrdersResponse,
              NormalizeTaskOrdersCommandHandler>(
          () => NormalizeTaskOrdersCommandHandler(taskRepository))
      ..registerHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse,
              NormalizeNoteOrdersCommandHandler>(
          () => NormalizeNoteOrdersCommandHandler(noteRepository));
    return ImportDataCommandHandler(
      appUsageRepository: DriftAppUsageRepository.withDatabase(db),
      appUsageTagRepository: DriftAppUsageTagRepository.withDatabase(db),
      appUsageTimeRecordRepository:
          DriftAppUsageTimeRecordRepository.withDatabase(db),
      appUsageTagRuleRepository:
          DriftAppUsageTagRuleRepository.withDatabase(db),
      habitRepository: habitRepository,
      habitRecordRepository: DriftHabitRecordRepository.withDatabase(db),
      habitTimeRecordRepository:
          DriftHabitTimeRecordRepository.withDatabase(db),
      habitTagRepository: DriftHabitTagRepository.withDatabase(db),
      tagRepository: DriftTagRepository.withDatabase(db),
      tagTagRepository: DriftTagTagRepository.withDatabase(db),
      taskRepository: taskRepository,
      taskStatusRepository: DriftTaskStatusRepository.withDatabase(db),
      taskTagRepository: DriftTaskTagRepository.withDatabase(db),
      taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(db),
      settingRepository: DriftSettingRepository.withDatabase(db),
      syncDeviceRepository: DriftSyncDeviceRepository.withDatabase(db),
      appUsageIgnoreRuleRepository:
          DriftAppUsageIgnoreRuleRepository.withDatabase(db),
      noteRepository: noteRepository,
      noteTagRepository: DriftNoteTagRepository.withDatabase(db),
      migrationService: _NoMigration(),
      compressionService: _JsonCompressionService(exportJson),
      syncMembership: membershipWired ? service : null,
      mediator: mediator,
    );
  }

  Future<void> replaceImport(String exportJson) {
    AppDatabase.setInstanceForTesting(appDatabase);
    return importHandler(exportJson)(
        ImportDataCommand(Uint8List(0), ImportStrategy.replace));
  }

  DemoDataService demoService() {
    final db = appDatabase;
    return DemoDataService(
      settingRepository: DriftSettingRepository.withDatabase(db),
      tagRepository: DriftTagRepository.withDatabase(db),
      taskRepository: DriftTaskRepository.withDatabase(db),
      taskTagRepository: DriftTaskTagRepository.withDatabase(db),
      taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(db),
      habitRepository: DriftHabitRepository.withDatabase(db),
      habitRecordRepository: DriftHabitRecordRepository.withDatabase(db),
      habitTagRepository: DriftHabitTagRepository.withDatabase(db),
      noteRepository: DriftNoteRepository.withDatabase(db),
      noteTagRepository: DriftNoteTagRepository.withDatabase(db),
      appUsageRepository: DriftAppUsageRepository.withDatabase(db),
      appUsageTimeRecordRepository:
          DriftAppUsageTimeRecordRepository.withDatabase(db),
      appUsageTagRepository: DriftAppUsageTagRepository.withDatabase(db),
      syncMembership: service,
    );
  }
}
