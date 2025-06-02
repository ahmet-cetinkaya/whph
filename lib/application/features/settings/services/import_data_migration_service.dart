import 'package:whph/application/features/settings/services/abstraction/i_import_data_migration_service.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/application/features/settings/constants/setting_translation_keys.dart';

/// Concrete implementation of import data migration service.
///
/// This service handles version-specific transformations for imported data,
/// applying migrations sequentially from the source version to the current version.
class ImportDataMigrationService implements IImportDataMigrationService {
  // Define migration versions in chronological order
  static const List<String> _migrationVersions = [
    '0.6.4',
    // Add future versions here as needed
    // '0.6.5',
    // '0.7.0',
    // etc.
  ];

  @override
  Future<Map<String, dynamic>> migrateData(Map<String, dynamic> data, String sourceVersion) async {
    // Check if the source version is the same as current version
    if (sourceVersion == AppInfo.version) {
      return data;
    }

    // Check if the source version is supported
    final sourceIndex = _migrationVersions.indexOf(sourceVersion);
    if (sourceIndex == -1) {
      throw BusinessException(
        'Unsupported source version: $sourceVersion',
        SettingTranslationKeys.unsupportedVersionError,
        args: {'version': sourceVersion},
      );
    }

    // Apply migrations sequentially from source version to current version
    Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);

    for (int i = sourceIndex; i < _migrationVersions.length - 1; i++) {
      final fromVersion = _migrationVersions[i];
      final toVersion = _migrationVersions[i + 1];
      migratedData = await _applyMigration(migratedData, fromVersion, toVersion);
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
    // Check if the source version is different from current version
    if (sourceVersion == AppInfo.version) {
      return false;
    }

    // Check if the source version is supported
    return _migrationVersions.contains(sourceVersion);
  }

  @override
  List<String> getAvailableMigrationVersions() {
    return List<String>.from(_migrationVersions);
  }

  /// Applies a specific migration from one version to another.
  ///
  /// [data] - The data to migrate
  /// [fromVersion] - The source version
  /// [toVersion] - The target version
  ///
  /// Returns the migrated data
  Future<Map<String, dynamic>> _applyMigration(
    Map<String, dynamic> data,
    String fromVersion,
    String toVersion,
  ) async {
    // Apply version-specific migrations
    switch ('${fromVersion}_to_$toVersion') {
      // Example migration from 0.6.4 to 0.6.5 (future version)
      // case '0.6.4_to_0.6.5':
      //   return await _migrateFrom064To065(data);

      default:
        // If no specific migration is needed, return data as-is
        return data;
    }
  }

  // Example migration method (for future use)
  // Future<Map<String, dynamic>> _migrateFrom064To065(Map<String, dynamic> data) async {
  //   // Perform specific transformations for this version change
  //   // For example:
  //   // - Rename fields
  //   // - Transform data structures
  //   // - Add default values for new fields
  //   // - Convert enum values
  //
  //   Map<String, dynamic> migratedData = Map<String, dynamic>.from(data);
  //
  //   // Example transformation:
  //   // if (migratedData['tasks'] != null) {
  //   //   final tasks = migratedData['tasks'] as List;
  //   //   for (var task in tasks) {
  //   //     if (task is Map<String, dynamic>) {
  //   //       // Add new field with default value
  //   //       task['newField'] = 'defaultValue';
  //   //
  //   //       // Transform priority enum values if needed
  //   //       if (task['priority'] != null) {
  //   //         task['priority'] = _transformPriorityValue(task['priority']);
  //   //       }
  //   //     }
  //   //   }
  //   // }
  //
  //   return migratedData;
  // }

  // Helper methods for common transformations can be added here

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
