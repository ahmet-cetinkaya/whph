import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'dart:convert';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/application/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'dart:io';
import 'package:whph/core/domain/shared/utils/logger.dart';

enum ImportStrategy { replace, merge }

class ImportDataCommand implements IRequest<ImportDataCommandResponse> {
  final Uint8List backupData;
  final ImportStrategy strategy;

  ImportDataCommand(this.backupData, this.strategy);
}

class ImportDataCommandResponse {}

class ImportConfig<T extends BaseEntity> {
  final String name;
  final IRepository repository;
  final T Function(Map<String, dynamic>) fromJson;

  ImportConfig({
    required this.name,
    required this.repository,
    required this.fromJson,
  });
}

class ImportDataCommandHandler implements IRequestHandler<ImportDataCommand, ImportDataCommandResponse> {
  final IAppUsageRepository appUsageRepository;
  final IAppUsageTagRepository appUsageTagRepository;
  final IAppUsageTimeRecordRepository appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository appUsageTagRuleRepository;
  final IHabitRepository habitRepository;
  final IHabitRecordRepository habitRecordRepository;
  final IHabitTagsRepository habitTagRepository;
  final ITagRepository tagRepository;
  final ITagTagRepository tagTagRepository;
  final ITaskRepository taskRepository;
  final ITaskTagRepository taskTagRepository;
  final ITaskTimeRecordRepository taskTimeRecordRepository;
  final ISettingRepository settingRepository;
  final ISyncDeviceRepository syncDeviceRepository;
  final IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository;
  final INoteRepository noteRepository;
  final INoteTagRepository noteTagRepository;
  final IImportDataMigrationService migrationService;
  final ICompressionService compressionService;

  late final List<ImportConfig> _importConfigs;

  ImportDataCommandHandler({
    required this.appUsageRepository,
    required this.appUsageTagRepository,
    required this.appUsageTimeRecordRepository,
    required this.appUsageTagRuleRepository,
    required this.habitRepository,
    required this.habitRecordRepository,
    required this.habitTagRepository,
    required this.tagRepository,
    required this.tagTagRepository,
    required this.taskRepository,
    required this.taskTagRepository,
    required this.taskTimeRecordRepository,
    required this.settingRepository,
    required this.syncDeviceRepository,
    required this.appUsageIgnoreRuleRepository,
    required this.noteRepository,
    required this.noteTagRepository,
    required this.migrationService,
    required this.compressionService,
  }) {
    _importConfigs = [
      ImportConfig<Tag>(
        name: 'tags',
        repository: tagRepository,
        fromJson: (json) => JsonMapper.deserialize<Tag>(jsonEncode(json))!,
      ),
      ImportConfig<TagTag>(
        name: 'tagTags',
        repository: tagTagRepository,
        fromJson: (json) => JsonMapper.deserialize<TagTag>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsage>(
        name: 'appUsages',
        repository: appUsageRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsage>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTag>(
        name: 'appUsageTags',
        repository: appUsageTagRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTag>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTimeRecord>(
        name: 'appUsageTimeRecords',
        repository: appUsageTimeRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTimeRecord>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTagRule>(
        name: 'appUsageTagRules',
        repository: appUsageTagRuleRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTagRule>(jsonEncode(json))!,
      ),
      ImportConfig<Habit>(
        name: 'habits',
        repository: habitRepository,
        fromJson: (json) => JsonMapper.deserialize<Habit>(jsonEncode(json))!,
      ),
      ImportConfig<HabitRecord>(
        name: 'habitRecords',
        repository: habitRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<HabitRecord>(jsonEncode(json))!,
      ),
      ImportConfig<HabitTag>(
        name: 'habitTags',
        repository: habitTagRepository,
        fromJson: (json) => JsonMapper.deserialize<HabitTag>(jsonEncode(json))!,
      ),
      ImportConfig<Task>(
        name: 'tasks',
        repository: taskRepository,
        fromJson: (json) => JsonMapper.deserialize<Task>(jsonEncode(json))!,
      ),
      ImportConfig<TaskTag>(
        name: 'taskTags',
        repository: taskTagRepository,
        fromJson: (json) => JsonMapper.deserialize<TaskTag>(jsonEncode(json))!,
      ),
      ImportConfig<TaskTimeRecord>(
        name: 'taskTimeRecords',
        repository: taskTimeRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<TaskTimeRecord>(jsonEncode(json))!,
      ),
      ImportConfig<Setting>(
        name: 'settings',
        repository: settingRepository,
        fromJson: (json) => JsonMapper.deserialize<Setting>(jsonEncode(json))!,
      ),
      ImportConfig<SyncDevice>(
        name: 'syncDevices',
        repository: syncDeviceRepository,
        fromJson: (json) => JsonMapper.deserialize<SyncDevice>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageIgnoreRule>(
        name: 'appUsageIgnoreRules',
        repository: appUsageIgnoreRuleRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageIgnoreRule>(jsonEncode(json))!,
      ),
      ImportConfig<Note>(
        name: 'notes',
        repository: noteRepository,
        fromJson: (json) => JsonMapper.deserialize<Note>(jsonEncode(json))!,
      ),
      ImportConfig<NoteTag>(
        name: 'noteTags',
        repository: noteTagRepository,
        fromJson: (json) => JsonMapper.deserialize<NoteTag>(jsonEncode(json))!,
      ),
    ];
  }

  /// Creates a backup of current database before import
  Future<File?> _createPreImportBackup() async {
    final dbInstance = AppDatabase.instance();
    final backupFile = await dbInstance.createDatabaseBackup();
    if (kDebugMode) {
      print('Pre-import backup created: ${backupFile?.path}');
    }
    // In test mode, backupFile is null which is acceptable
    // In production, throw if backup fails - this is critical for data safety
    if (backupFile == null && !kDebugMode) {
      throw BusinessException(
        'Failed to create pre-import backup. Cannot proceed with import.',
        SettingsTranslationKeys.backupCreateError,
      );
    }
    return backupFile;
  }

  /// Validates the structure of imported data
  void _validateImportData(Map<String, dynamic> data) {
    // Validate that data is not empty
    if (data.isEmpty) {
      throw BusinessException(
        'Import data is empty',
        SettingsTranslationKeys.backupInvalidFormatError,
      );
    }

    // Validate appInfo exists
    if (data['appInfo'] == null) {
      throw BusinessException(
        'No app information found in import data',
        SettingsTranslationKeys.backupInvalidFormatError,
      );
    }

    // Validate version exists
    if (data['appInfo']['version'] == null) {
      throw BusinessException(
        'No version information found in import data',
        SettingsTranslationKeys.versionMismatchError,
        args: {
          'importedVersion': 'unknown',
          'currentVersion': AppInfo.version,
        },
      );
    }

    if (kDebugMode) {
      print('Import data structure validated successfully');
    }
  }

  /// Validates data integrity after import
  Future<void> _validatePostImportIntegrity() async {
    try {
      final dbInstance = AppDatabase.instance();

      // Check foreign key integrity
      final violations = await dbInstance.customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw BusinessException(
          'Foreign key integrity violations detected after import: ${violations.length} violations',
          SettingsTranslationKeys.importFailedError,
          args: {'error': 'Data integrity check failed'},
        );
      }

      if (kDebugMode) {
        print('Post-import data integrity validation passed');
      }
    } on BusinessException {
      // Re-throw business exceptions as-is
      rethrow;
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error during post-import integrity check',
        error: e,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        print('Post-import integrity check failed: $e');
      }
      throw BusinessException(
        'Failed to validate data integrity after import: ${e.toString()}',
        SettingsTranslationKeys.integrityCheckError,
      );
    }
  }

  @override
  Future<ImportDataCommandResponse> call(ImportDataCommand request) async {
    File? preImportBackup;

    try {
      if (kDebugMode) {
        print('Starting import process with strategy: ${request.strategy}');
      }

      // Create backup before import
      preImportBackup = await _createPreImportBackup();

      // Validate header
      if (!compressionService.validateHeader(request.backupData)) {
        throw BusinessException(
          'Invalid backup file format',
          SettingsTranslationKeys.backupInvalidFormatError,
        );
      }

      // Validate checksum
      final isValidChecksum = await compressionService.validateChecksum(request.backupData);
      if (!isValidChecksum) {
        throw BusinessException(
          'Backup file is corrupted',
          SettingsTranslationKeys.backupCorruptedError,
        );
      }

      // Extract and decompress data
      final jsonString = await compressionService.extractFromWhphFile(request.backupData);

      // Validate JSON can be decoded
      Map<String, dynamic> data;
      try {
        data = json.decode(jsonString);
      } catch (e) {
        throw BusinessException(
          'Failed to parse backup file: Invalid JSON format',
          SettingsTranslationKeys.backupInvalidFormatError,
        );
      }

      // Validate data structure
      _validateImportData(data);

      // Get the imported version
      final importedVersion = data['appInfo']?['version'] as String?;
      if (importedVersion == null) {
        throw BusinessException(
          'No version information found in imported data',
          SettingsTranslationKeys.versionMismatchError,
          args: {
            'importedVersion': 'unknown',
            'currentVersion': AppInfo.version,
          },
        );
      }

      if (kDebugMode) {
        print('Importing data from version: $importedVersion');
      }

      // Check if migration is needed and apply it
      if (migrationService.isMigrationNeeded(importedVersion)) {
        try {
          if (kDebugMode) {
            print('Migrating data from version $importedVersion to ${AppInfo.version}');
          }
          data = await migrationService.migrateData(data, importedVersion);
        } catch (e) {
          throw BusinessException(
            'Failed to migrate data from version $importedVersion',
            SettingsTranslationKeys.migrationFailedError,
            args: {
              'importedVersion': importedVersion,
              'currentVersion': AppInfo.version,
              'error': e.toString(),
            },
          );
        }
      } else if (importedVersion != AppInfo.version) {
        // If version is different but no migration is needed:
        // 1. If imported version is older, it's compatible (patch update or no schema changes), so we allow it.
        // 2. If imported version is newer, we block it (downgrade not supported).
        final SemanticVersion importedSemVer;
        final SemanticVersion currentSemVer;

        try {
          importedSemVer = SemanticVersion.parse(importedVersion);
          currentSemVer = SemanticVersion.parse(AppInfo.version);
        } on FormatException {
          throw BusinessException(
            'Invalid version format in imported data',
            SettingsTranslationKeys.backupInvalidFormatError,
            args: {'version': importedVersion},
          );
        } catch (e, stackTrace) {
          Logger.error(
            'Unexpected error while parsing semantic versions',
            error: e,
            stackTrace: stackTrace,
          );
          throw BusinessException(
            'Failed to parse version information',
            SettingsTranslationKeys.versionParseError,
            args: {'importedVersion': importedVersion, 'currentVersion': AppInfo.version},
          );
        }

        if (importedSemVer > currentSemVer) {
          throw BusinessException(
            'Unsupported version in imported data (Newer version)',
            SettingsTranslationKeys.versionMismatchError,
            args: {
              'importedVersion': importedVersion,
              'currentVersion': AppInfo.version,
            },
          );
        }

        // If older, we proceed (fall through)
      }

      // Execute import operations in a transaction
      final dbInstance = AppDatabase.instance();
      await dbInstance.transaction(() async {
        if (request.strategy == ImportStrategy.replace) {
          if (kDebugMode) {
            print('Clearing all existing data (replace strategy)');
          }
          await _clearAllData();
        }

        // Import data sequentially using configs
        int totalImported = 0;
        for (final config in _importConfigs) {
          if (data[config.name] != null) {
            final items = (data[config.name] as List).cast<Map<String, dynamic>>();
            if (kDebugMode) {
              print('Importing ${items.length} items for ${config.name}');
            }
            await _importDataWithConfig(items, config, request.strategy);
            totalImported += items.length;
          }
        }

        if (kDebugMode) {
          print('Import completed successfully: $totalImported total items imported');
        }

        // Validate data integrity after import
        await _validatePostImportIntegrity();
      });

      // Clean up backup on success (optional)
      if (preImportBackup != null && preImportBackup.existsSync()) {
        if (kDebugMode) {
          print('Import successful, backup available at: ${preImportBackup.path}');
        }
      }

      return ImportDataCommandResponse();
    } catch (e, stackTrace) {
      // Always log errors for production debugging
      Logger.error(
        'Import failed with strategy: ${request.strategy}',
        error: e,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        print('CRITICAL: Import failed: $e');
        print('Stack trace: $stackTrace');
        if (preImportBackup != null && preImportBackup.existsSync()) {
          print('Pre-import backup available for recovery: ${preImportBackup.path}');
        }
      }

      // Transaction will automatically rollback
      rethrow;
    }
  }

  Future<void> _clearAllData() async {
    await Future.wait([
      appUsageRepository.truncate(),
      appUsageTagRepository.truncate(),
      appUsageTimeRecordRepository.truncate(),
      appUsageTagRuleRepository.truncate(),
      habitRepository.truncate(),
      habitRecordRepository.truncate(),
      habitTagRepository.truncate(),
      tagRepository.truncate(),
      tagTagRepository.truncate(),
      taskRepository.truncate(),
      taskTagRepository.truncate(),
      taskTimeRecordRepository.truncate(),
      noteRepository.truncate(),
      noteTagRepository.truncate(),
      settingRepository.truncate(),
      syncDeviceRepository.truncate(),
      appUsageIgnoreRuleRepository.truncate(),
    ]);
  }

  Future<void> _importDataWithConfig(
      List<Map<String, dynamic>> items, ImportConfig config, ImportStrategy strategy) async {
    try {
      // Validate items list is not null and convert safely
      if (items.isEmpty) {
        if (kDebugMode) {
          print('No items to import for ${config.name}');
        }
        return;
      }

      // Validate for duplicate IDs within the import batch
      final seenIds = <String>{};
      final duplicateIds = <String>{};
      for (var item in items) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (!seenIds.add(id)) {
            duplicateIds.add(id);
          }
        }
      }

      if (duplicateIds.isNotEmpty) {
        if (kDebugMode) {
          print('WARNING: Found ${duplicateIds.length} duplicate IDs in import data for ${config.name}');
          print('Duplicate IDs: ${duplicateIds.take(5).join(', ')}${duplicateIds.length > 5 ? '...' : ''}');
        }
        throw BusinessException(
          'Import data contains ${duplicateIds.length} duplicate IDs for ${config.name}',
          SettingsTranslationKeys.importFailedError,
          args: {
            'entity': config.name,
            'error': 'Duplicate IDs found: ${duplicateIds.take(3).join(', ')}${duplicateIds.length > 3 ? '...' : ''}',
          },
        );
      }

      int successCount = 0;
      int skippedCount = 0;
      for (var item in items) {
        try {
          // Null safety: validate item is not null
          if (item.isEmpty) {
            if (kDebugMode) {
              print('Skipping empty item in ${config.name}');
            }
            continue;
          }

          // Validate required ID field exists
          if (item['id'] == null || (item['id'] is String && (item['id'] as String).isEmpty)) {
            skippedCount++;
            Logger.warning('Skipping item with missing or empty ID in ${config.name}');
            if (kDebugMode) {
              print('Skipping item with missing or empty ID in ${config.name}');
            }
            continue;
          }

          // Convert CSV data to correct types with null safety
          if (config.name == 'tasks') {
            if (item['priority'] != null) {
              // Handle both string and int priority values
              if (item['priority'] is String) {
                final priorityStr = (item['priority'] as String).trim();
                switch (priorityStr.toLowerCase()) {
                  case 'urgentimportant':
                    item['priority'] = 0;
                    break;
                  case 'urgent':
                    item['priority'] = 1;
                    break;
                  case 'important':
                    item['priority'] = 2;
                    break;
                  case 'neither':
                    item['priority'] = 3;
                    break;
                  default:
                    Logger.warning(
                      'Unknown priority value "$priorityStr" in task ${item['id']}, defaulting to Neither (3)',
                    );
                    item['priority'] = 3; // Default to neither if unknown
                }
              } else if (item['priority'] is! int) {
                Logger.warning(
                  'Unexpected priority type in task ${item['id']}, defaulting to Neither (3)',
                );
                item['priority'] = 3; // Default to neither if type is unexpected
              }
            }
            if (item['isCompleted'] != null && item['isCompleted'] is String) {
              item['isCompleted'] = (item['isCompleted'] as String).toLowerCase() == 'true';
            }
          }

          // Deserialize entity
          final entity = config.fromJson(item);

          if (strategy == ImportStrategy.merge) {
            final existing = await config.repository.getById(entity.id);
            if (existing != null) {
              await config.repository.update(entity);
              successCount++;
              continue;
            }
          }

          await config.repository.add(entity);
          successCount++;
        } catch (itemError, itemStack) {
          if (kDebugMode) {
            print('Failed to import item in ${config.name}:');
            print('Item data: $item');
            print('Error: $itemError');
            print('Stack trace: $itemStack');
          }
          rethrow;
        }
      }

      // Log summary of skipped items
      if (skippedCount > 0) {
        Logger.warning(
          'Skipped $skippedCount items with missing IDs during import of ${config.name}',
        );
        // Throw if too many items skipped (indicates corrupted backup)
        if (skippedCount > items.length * 0.1) {
          throw BusinessException(
            'Too many items ($skippedCount/${items.length}) with missing IDs in ${config.name}. '
            'Backup file may be corrupted.',
            SettingsTranslationKeys.importDataIntegrityError,
            args: {
              'entity': config.name,
              'skipped': skippedCount.toString(),
              'total': items.length.toString(),
            },
          );
        }
      }

      if (kDebugMode) {
        print('Successfully imported $successCount/${items.length} items for ${config.name}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Import error in ${config.name}: $e');
        print('Stack trace: $stackTrace');
      }
      throw BusinessException(
        'Import error while processing ${config.name}: ${e.toString()}',
        SettingsTranslationKeys.importFailedError,
        args: {
          'entity': config.name,
          'error': e.toString(),
        },
      );
    }
  }
}
