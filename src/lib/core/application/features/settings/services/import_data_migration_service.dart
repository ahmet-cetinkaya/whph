import 'package:whph/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/settings/constants/settings_translation_keys.dart';

/// Concrete implementation of import data migration service.
///
/// This service handles version-specific transformations for imported data using semantic versioning.
/// Migrations are defined only when needed between specific versions and applied incrementally.
class ImportDataMigrationService implements IImportDataMigrationService {
  final MigrationRegistry _migrationRegistry = MigrationRegistry();

  ImportDataMigrationService() {
    _registerMigrations();
  }

  /// Registers all available migrations.
  ///
  /// Add new migrations here when they are needed for future versions.
  void _registerMigrations() {
    _migrationRegistry.registerMigration(
      fromVersion: '0.6.9',
      toVersion: '0.6.10',
      description: 'Add usageDate field to AppUsageTimeRecord entities',
      migrationFunction: _migrate0_6_9to0_6_10,
    );

    _migrationRegistry.registerMigration(
      fromVersion: '0.14.1',
      toVersion: '0.15.0',
      description: 'Migrate HabitRecord date field to occurredAt',
      migrationFunction: _migrate0_14_1to0_15_0,
    );

    _migrationRegistry.registerMigration(
      fromVersion: '0.15.0',
      toVersion: '0.16.0',
      description: 'Migrate task isCompleted to completedAt and add habit time tracking fields',
      migrationFunction: _migrate0_15_0to0_16_0,
    );

    _migrationRegistry.registerMigration(
      fromVersion: '0.16.0',
      toVersion: '0.20.0',
      description: 'Add habit status, task recurrence, tag type and order',
      migrationFunction: _migrate0_16_0to0_20_0,
    );
  }

  @override
  Future<Map<String, dynamic>> migrateData(Map<String, dynamic> data, String sourceVersion) async {
    final currentVersion = SemanticVersion.parse(AppInfo.version);

    SemanticVersion sourceSemanticVersion;
    try {
      sourceSemanticVersion = SemanticVersion.parse(sourceVersion);
    } catch (e) {
      throw BusinessException(
        'Invalid source version format: $sourceVersion',
        SettingsTranslationKeys.unsupportedVersionError,
        args: {'version': sourceVersion},
      );
    }

    // No migration needed if source is same or newer than current
    if (sourceSemanticVersion >= currentVersion) {
      return data;
    }

    final migrationSteps = _migrationRegistry.getMigrationPath(sourceSemanticVersion, currentVersion);

    // If no specific migrations are defined, return data with updated version info.
    // This covers versions between defined migration points that are still compatible.
    if (migrationSteps.isEmpty) {
      final migratedData = Map<String, dynamic>.from(data);
      migratedData['appInfo'] = {
        ...migratedData['appInfo'] ?? {},
        'version': AppInfo.version,
      };
      return migratedData;
    }

    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    for (final step in migrationSteps) {
      try {
        migratedData = await step.migrationFunction(migratedData);
      } on BusinessException catch (e, stackTrace) {
        // Expected validation failures - log as warnings
        Logger.warning(
          'Migration validation failed in step (${step.fromVersion} -> ${step.toVersion}): ${step.description}. '
          'Error: ${e.message}',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      } catch (e, stackTrace) {
        // Unexpected bugs - log as errors with full context
        Logger.error(
          'Unexpected error in migration step (${step.fromVersion} -> ${step.toVersion}): ${step.description}. '
          'Error: $e',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    migratedData['appInfo'] = {
      ...migratedData['appInfo'] ?? {},
      'version': AppInfo.version,
    };

    return migratedData;
  }

  @override
  bool isMigrationNeeded(String sourceVersion) {
    try {
      final currentVersion = SemanticVersion.parse(AppInfo.version);
      final sourceSemanticVersion = SemanticVersion.parse(sourceVersion);

      if (sourceSemanticVersion >= currentVersion) {
        return false;
      }

      final migrationSteps = _migrationRegistry.getMigrationPath(sourceSemanticVersion, currentVersion);

      if (migrationSteps.isNotEmpty) {
        return true;
      }

      // No migration steps needed - version will be updated during import
      return false;
    } catch (e, stackTrace) {
      Logger.error(
        'Invalid version format when checking if migration is needed: $sourceVersion',
        error: e,
        stackTrace: stackTrace,
      );
      throw BusinessException(
        'Invalid version format in backup data: $sourceVersion',
        SettingsTranslationKeys.backupInvalidFormatError,
        args: {'version': sourceVersion},
      );
    }
  }

  @override
  List<String> getAvailableMigrationVersions() {
    final versions = <String>{};

    for (final step in _migrationRegistry.registeredMigrations) {
      versions.add(step.fromVersion.toString());
      versions.add(step.toVersion.toString());
    }

    versions.add(AppInfo.version);

    final sortedVersions = versions.toList();
    sortedVersions.sort((a, b) => SemanticVersion.parse(a).compareTo(SemanticVersion.parse(b)));

    return sortedVersions;
  }

  /// Migration from 0.6.9 to 0.6.10
  ///
  /// This migration adds the usageDate field to AppUsageTimeRecord entities.
  /// Schema version: 20 → 21
  Future<Map<String, dynamic>> _migrate0_6_9to0_6_10(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    if (migratedData['appUsageTimeRecords'] != null) {
      final appUsageTimeRecords = migratedData['appUsageTimeRecords'] as List;
      for (var record in appUsageTimeRecords) {
        if (record is Map<String, dynamic>) {
          // Use createdDate as the initial usageDate to maintain compatibility
          if (!record.containsKey('usageDate') && record.containsKey('createdDate')) {
            record['usageDate'] = record['createdDate'];
          }
        }
      }
    }

    return migratedData;
  }

  /// Migration from 0.14.1 to 0.15.0
  ///
  /// Handles the HabitRecord schema change from `date` to `occurredAt`. Schema: 23 → 24.
  /// - Renamed HabitRecord.date to HabitRecord.occurredAt
  /// - Created HabitTimeRecord table
  Future<Map<String, dynamic>> _migrate0_14_1to0_15_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          if (!record.containsKey('occurredAt') && record.containsKey('date')) {
            record['occurredAt'] = record['date'];
            record.remove('date');
          }
          // Fallback to createdDate if both fields are missing
          else if (!record.containsKey('occurredAt') && record.containsKey('createdDate')) {
            record['occurredAt'] = record['createdDate'];
          }
        }
      }
    }

    return migratedData;
  }

  /// Migration from 0.15.0 to 0.16.0
  ///
  /// Handles schema changes across versions 24-28 including isCompleted→completedAt,
  /// HabitTimeRecord fields, and isEstimated flag.
  Future<Map<String, dynamic>> _migrate0_15_0to0_16_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    // isCompleted → completedAt: provides better completion tracking (Schema 28)
    if (migratedData['tasks'] != null) {
      final tasks = migratedData['tasks'] as List;
      for (var task in tasks) {
        if (task is Map<String, dynamic>) {
          if (!task.containsKey('completedAt') && task.containsKey('isCompleted')) {
            if (task['isCompleted'] == true) {
              // Best estimate of when the task was completed
              task['completedAt'] =
                  task['modifiedDate'] ?? task['createdDate'] ?? DateTime.now().toUtc().toIso8601String();
            } else {
              task['completedAt'] = null;
            }
          }
          task.remove('isCompleted');
        }
      }
    }

    // HabitTimeRecord: Add occurredAt (Schema 25) and isEstimated (Schema 27)
    if (migratedData['habitTimeRecords'] != null) {
      final habitTimeRecords = migratedData['habitTimeRecords'] as List;
      for (var record in habitTimeRecords) {
        if (record is Map<String, dynamic>) {
          // Tracks when the time was actually spent
          if (!record.containsKey('occurredAt') && record.containsKey('createdDate')) {
            record['occurredAt'] = record['createdDate'];
          }

          // Existing records were manually logged (not estimated)
          if (!record.containsKey('isEstimated')) {
            record['isEstimated'] = false;
          }
        }
      }
    }

    // Ensure HabitRecord.occurredAt exists - handles edge cases
    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          if (!record.containsKey('occurredAt') && record.containsKey('createdDate')) {
            record['occurredAt'] = record['createdDate'];
          }
        }
      }
    }

    return migratedData;
  }

  /// Migration from 0.16.0 to 0.20.0
  ///
  /// Handles schemas 30-33: HabitRecord status, Task recurrenceConfiguration,
  /// Tag type, and tagOrder on relations.
  Future<Map<String, dynamic>> _migrate0_16_0to0_20_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          if (!record.containsKey('status')) {
            record['status'] = 0; // Default: Pending/Skipped
          }
        }
      }
    }

    if (migratedData['tasks'] != null) {
      final tasks = migratedData['tasks'] as List;
      for (var task in tasks) {
        if (task is Map<String, dynamic>) {
          if (!task.containsKey('recurrenceConfiguration')) {
            task['recurrenceConfiguration'] = null;
          }
          if (!task.containsKey('plannedDateReminderCustomOffset')) {
            task['plannedDateReminderCustomOffset'] = null;
          }
          if (!task.containsKey('deadlineDateReminderCustomOffset')) {
            task['deadlineDateReminderCustomOffset'] = null;
          }
        }
      }
    }

    if (migratedData['tags'] != null) {
      final tags = migratedData['tags'] as List;
      for (var tag in tags) {
        if (tag is Map<String, dynamic>) {
          if (!tag.containsKey('type')) {
            tag['type'] = 0; // Default: Label
          }
        }
      }
    }

    final relationTables = ['taskTags', 'noteTags', 'habitTags', 'appUsageTags'];
    for (final tableName in relationTables) {
      if (migratedData[tableName] != null) {
        final relations = migratedData[tableName] as List;
        for (var relation in relations) {
          if (relation is Map<String, dynamic>) {
            if (!relation.containsKey('tagOrder')) {
              relation['tagOrder'] = 0;
            }
          }
        }
      }
    }

    return migratedData;
  }

  // Helper methods for common transformations

  /// Transforms priority enum values between versions.
  /// Useful when enum order changes between versions.
  // ignore: unused_element
  int? _transformPriorityValue(dynamic priority) {
    if (priority == null) return null;
    if (priority is int) return priority;
    if (priority is String) {
      return int.tryParse(priority);
    }
    return null;
  }

  /// Transforms date/time values between versions.
  /// Useful when date format changes between versions.
  // ignore: unused_element
  String? _transformDateTimeValue(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is String) return dateTime;
    if (dateTime is DateTime) return dateTime.toIso8601String();
    return null;
  }

  /// Adds missing fields with default values for a specific entity type.
  /// Useful when new required fields are added in newer versions.
  // ignore: unused_element
  Map<String, dynamic> _addMissingFieldsWithDefaults(
    Map<String, dynamic> entity,
    Map<String, dynamic> defaultValues,
  ) {
    final updatedEntity = Map<String, dynamic>.from(entity);

    for (final entry in defaultValues.entries) {
      if (!updatedEntity.containsKey(entry.key)) {
        updatedEntity[entry.key] = entry.value;
      }
    }

    return updatedEntity;
  }

  /// Removes deprecated fields that are no longer used in newer versions.
  // ignore: unused_element
  Map<String, dynamic> _removeDeprecatedFields(
    Map<String, dynamic> entity,
    List<String> deprecatedFields,
  ) {
    final updatedEntity = Map<String, dynamic>.from(entity);

    for (final field in deprecatedFields) {
      updatedEntity.remove(field);
    }

    return updatedEntity;
  }
}
