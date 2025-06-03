import 'package:whph/src/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
import 'package:whph/src/core/application/features/settings/constants/setting_translation_keys.dart';
import 'package:whph/src/core/domain/shared/utilities/semantic_version.dart';
import 'package:whph/src/core/domain/shared/utilities/migration_registry.dart';

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
    // Example migration for future version 1.1.0
    // _migrationRegistry.registerMigration(
    //   fromVersion: '1.0.0',
    //   toVersion: '1.1.0',
    //   description: 'Add new task fields and update priority system',
    //   migrationFunction: _migrateFrom100To110,
    // );

    // Currently no migrations are defined between 0.6.4 and 1.0.0
    // This means if imported data version is 0.6.4 and current app version is 1.0.0,
    // no processing will be done and data will be returned as-is.
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
        SettingTranslationKeys.unsupportedVersionError,
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

    // If no specific migrations are defined, return data as-is
    // This covers the case where imported data is 0.6.4 and current app is 1.0.0
    // with no specific migrations defined between these versions
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
      migratedData = await step.migrationFunction(migratedData);
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
      // and there are specific migration steps defined
      if (sourceSemanticVersion >= currentVersion) {
        return false;
      }

      final migrationSteps = _migrationRegistry.getMigrationPath(sourceSemanticVersion, currentVersion);
      return migrationSteps.isNotEmpty;
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

  // Example migration method for future use
  // Future<Map<String, dynamic>> _migrateFrom100To110(Map<String, dynamic> data) async {
  //   Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);
  //
  //   // Example: Add new task fields
  //   if (migratedData['tasks'] != null) {
  //     final tasks = migratedData['tasks'] as List;
  //     for (var task in tasks) {
  //       if (task is Map<String, dynamic>) {
  //         // Add new field with default value
  //         task['estimatedDuration'] = task['estimatedDuration'] ?? 0;
  //         task['actualDuration'] = task['actualDuration'] ?? 0;
  //
  //         // Transform priority system if needed
  //         if (task['priority'] != null) {
  //           task['priority'] = _transformPriorityValue(task['priority']);
  //         }
  //       }
  //     }
  //   }
  //
  //   return migratedData;
  // }

  // Helper methods for common transformations

  /// Transforms priority enum values between versions if needed.
  /// This is useful when enum order changes between versions.
  ///
  /// Example usage in migration methods:
  /// ```dart
  /// task['priority'] = _transformPriorityValue(task['priority']);
  /// ```
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
  ///
  /// Example usage in migration methods:
  /// ```dart
  /// entity['updatedAt'] = _transformDateTimeValue(entity['updatedAt']);
  /// ```
  // ignore: unused_element
  String? _transformDateTimeValue(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is String) return dateTime;
    if (dateTime is DateTime) return dateTime.toIso8601String();
    return null;
  }

  /// Adds missing fields with default values for a specific entity type.
  /// This is useful when new required fields are added in newer versions.
  ///
  /// Example usage in migration methods:
  /// ```dart
  /// entity = _addMissingFieldsWithDefaults(entity, {'newField': 'defaultValue'});
  /// ```
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
  ///
  /// Example usage in migration methods:
  /// ```dart
  /// entity = _removeDeprecatedFields(entity, ['oldField1', 'oldField2']);
  /// ```
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
