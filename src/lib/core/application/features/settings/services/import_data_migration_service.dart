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
    // Migration from 0.6.9 to 0.6.10: Add usageDate field to AppUsageTimeRecord entities
    _migrationRegistry.registerMigration(
      fromVersion: '0.6.9',
      toVersion: '0.6.10',
      description: 'Add usageDate field to AppUsageTimeRecord entities',
      migrationFunction: _migrate0_6_9to0_6_10,
    );

    // Migration from 0.14.1 to 0.15.0: Migrate HabitRecord date to occurredAt
    _migrationRegistry.registerMigration(
      fromVersion: '0.14.1',
      toVersion: '0.15.0',
      description: 'Migrate HabitRecord date field to occurredAt',
      migrationFunction: _migrate0_14_1to0_15_0,
    );

    // Migration from 0.15.0 to 0.16.0: Migrate task isCompleted to completedAt and add habit time tracking fields
    _migrationRegistry.registerMigration(
      fromVersion: '0.15.0',
      toVersion: '0.16.0',
      description: 'Migrate task isCompleted to completedAt and add habit time tracking fields',
      migrationFunction: _migrate0_15_0to0_16_0,
    );

    // Migration from 0.16.0 to 0.20.0: Add habit status, task recurrence, tag type and order
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

    // Check if migration is needed
    if (sourceSemanticVersion >= currentVersion) {
      // Source version is same or newer than current version, no migration needed
      return data;
    }

    // Get migration path from source to current version
    final migrationSteps = _migrationRegistry.getMigrationPath(sourceSemanticVersion, currentVersion);

    // If no specific migrations are defined, return data with updated version info
    // This covers the case where imported data is from a version that doesn't have specific migrations
    // but is still compatible (e.g., patch versions or versions between defined migration points)
    if (migrationSteps.isEmpty) {
      // Update the app version in the data to reflect current version
      final migratedData = Map<String, dynamic>.from(data);
      migratedData['appInfo'] = {
        ...migratedData['appInfo'] ?? {},
        'version': AppInfo.version,
      };
      return migratedData;
    }

    // Apply migrations sequentially
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    for (final step in migrationSteps) {
      try {
        migratedData = await step.migrationFunction(migratedData);
      } catch (e, stackTrace) {
        Logger.error(
          'Migration failed in step (${step.fromVersion} -> ${step.toVersion}): $e',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    // Update the app version in the migrated data
    migratedData['appInfo'] = {
      ...migratedData['appInfo'] ?? {},
      'version': AppInfo.version,
    };

    return migratedData;
  }

  @override
  bool isMigrationNeeded(String sourceVersion) {
    final currentVersion = SemanticVersion.parse(AppInfo.version);

    try {
      final sourceSemanticVersion = SemanticVersion.parse(sourceVersion);

      // Migration is needed if source version is older than current version
      if (sourceSemanticVersion >= currentVersion) {
        return false;
      }

      // Check if there are specific migration steps defined for the version range
      final migrationSteps = _migrationRegistry.getMigrationPath(sourceSemanticVersion, currentVersion);

      // If there are specific migrations defined, then migration is needed
      if (migrationSteps.isNotEmpty) {
        return true;
      }

      // If no specific migrations are defined, no migration is needed
      // The version will be updated during import without requiring migration steps
      return false;
    } catch (e) {
      // Invalid version format
      return false;
    }
  }

  @override
  List<String> getAvailableMigrationVersions() {
    // Return all versions that have migrations defined
    final versions = <String>{};

    for (final step in _migrationRegistry.registeredMigrations) {
      versions.add(step.fromVersion.toString());
      versions.add(step.toVersion.toString());
    }

    // Also include current app version
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

    // Migrate AppUsageTimeRecord entities to add usageDate field
    if (migratedData['appUsageTimeRecords'] != null) {
      final appUsageTimeRecords = migratedData['appUsageTimeRecords'] as List;
      for (var record in appUsageTimeRecords) {
        if (record is Map<String, dynamic>) {
          // Add usageDate field if it doesn't exist
          // Use createdDate as the initial value for usageDate to maintain compatibility
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
  /// This migration handles the HabitRecord schema change from `date` to `occurredAt`.
  /// Schema version: 23 → 24
  ///
  /// Database migration (from23To24):
  /// - Renamed HabitRecord.date to HabitRecord.occurredAt (non-nullable)
  /// - Created HabitTimeRecord table for tracking habit time
  Future<Map<String, dynamic>> _migrate0_14_1to0_15_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    // Migrate HabitRecord entities: date → occurredAt
    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          // If occurredAt doesn't exist but date does, perform migration
          if (!record.containsKey('occurredAt') && record.containsKey('date')) {
            record['occurredAt'] = record['date'];
            // Remove the deprecated date field
            record.remove('date');
          }
          // Ensure occurredAt exists (fallback to createdDate if both fields are missing)
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
  /// This migration handles multiple schema changes across versions 24-28:
  ///
  /// Schema 25 (v0.15.0+):
  /// - HabitTimeRecord: Added occurredAt field (nullable)
  ///
  /// Schema 27 (v0.16.0):
  /// - HabitTimeRecord: Added isEstimated field to distinguish manual vs estimated time
  ///
  /// Schema 28 (v0.16.0):
  /// - Task: Replaced isCompleted boolean with completedAt timestamp
  ///
  /// This migration ensures data compatibility when importing from v0.15.0 to v0.16.0.
  Future<Map<String, dynamic>> _migrate0_15_0to0_16_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    // 1. Migrate Task entities: isCompleted → completedAt (Schema 28)
    // This is a breaking change that provides better completion tracking
    if (migratedData['tasks'] != null) {
      final tasks = migratedData['tasks'] as List;
      for (var task in tasks) {
        if (task is Map<String, dynamic>) {
          // If completedAt doesn't exist but isCompleted does, perform migration
          if (!task.containsKey('completedAt') && task.containsKey('isCompleted')) {
            if (task['isCompleted'] == true) {
              // Use modifiedDate if available, otherwise createdDate, otherwise current time
              // This provides the best estimate of when the task was completed
              task['completedAt'] =
                  task['modifiedDate'] ?? task['createdDate'] ?? DateTime.now().toUtc().toIso8601String();
            } else {
              task['completedAt'] = null;
            }
          }
          // Remove the deprecated isCompleted field to clean up legacy data
          task.remove('isCompleted');
        }
      }
    }

    // 2. Migrate HabitTimeRecord entities: Add new tracking fields (Schema 25, 27)
    if (migratedData['habitTimeRecords'] != null) {
      final habitTimeRecords = migratedData['habitTimeRecords'] as List;
      for (var record in habitTimeRecords) {
        if (record is Map<String, dynamic>) {
          // Add occurredAt field if it doesn't exist (Schema 25)
          // This field tracks when the time was actually spent
          if (!record.containsKey('occurredAt') && record.containsKey('createdDate')) {
            record['occurredAt'] = record['createdDate'];
          }

          // Add isEstimated field with default value false (Schema 27)
          // Existing records are assumed to be manually logged (not estimated)
          if (!record.containsKey('isEstimated')) {
            record['isEstimated'] = false;
          }
        }
      }
    }

    // 3. Validate HabitRecord entities: Ensure occurredAt exists
    // This handles any edge cases where the field might be missing
    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          // Ensure occurredAt field exists (fallback to createdDate if missing)
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
  /// This migration handles schema changes introduced in v0.20.0 (Schemas 30-33):
  /// - HabitRecord: Add status (default 0)
  /// - Task: Add recurrenceConfiguration (default null)
  /// - Tag: Add type (default 0 - Label)
  /// - Relations: Add tagOrder (default 0)
  Future<Map<String, dynamic>> _migrate0_16_0to0_20_0(Map<String, dynamic> data) async {
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    // 1. Migrate HabitRecord entities: Add status
    if (migratedData['habitRecords'] != null) {
      final habitRecords = migratedData['habitRecords'] as List;
      for (var record in habitRecords) {
        if (record is Map<String, dynamic>) {
          if (!record.containsKey('status')) {
            record['status'] = 0; // Default status: Pending/Skipped (0)
          }
        }
      }
    }

    // 2. Migrate Task entities: Add recurrenceConfiguration
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

    // 3. Migrate Tag entities: Add type
    if (migratedData['tags'] != null) {
      final tags = migratedData['tags'] as List;
      for (var tag in tags) {
        if (tag is Map<String, dynamic>) {
          if (!tag.containsKey('type')) {
            tag['type'] = 0; // Default type: Label (0)
          }
        }
      }
    }

    // 4. Migrate Relations: Add tagOrder
    final relationTables = ['taskTags', 'noteTags', 'habitTags', 'appUsageTags'];
    for (final tableName in relationTables) {
      if (migratedData[tableName] != null) {
        final relations = migratedData[tableName] as List;
        for (var relation in relations) {
          if (relation is Map<String, dynamic>) {
            // Only add tagOrder for tables that need it (strictly relations)
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

  /// Transforms priority enum values between versions if needed.
  /// This is useful when enum order changes between versions.
  // ignore: unused_element
  int? _transformPriorityValue(dynamic priority) {
    if (priority == null) return null;
    if (priority is int) return priority;
    if (priority is String) {
      // Handle string-to-int conversion if needed
      return int.tryParse(priority);
    }
    return null;
  }

  /// Transforms date/time values between versions if needed.
  /// This is useful when date format changes between versions.
  // ignore: unused_element
  String? _transformDateTimeValue(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is String) return dateTime;
    if (dateTime is DateTime) return dateTime.toIso8601String();
    return null;
  }

  /// Adds missing fields with default values for a specific entity type.
  /// This is useful when new required fields are added in newer versions.
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
