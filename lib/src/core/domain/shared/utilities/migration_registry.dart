import 'package:whph/src/core/domain/shared/utilities/semantic_version.dart';

/// Represents a single migration step between two versions.
class MigrationStep {
  final SemanticVersion fromVersion;
  final SemanticVersion toVersion;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data) migrationFunction;
  final String description;

  const MigrationStep({
    required this.fromVersion,
    required this.toVersion,
    required this.migrationFunction,
    required this.description,
  });
}

/// Registry for managing data migration steps between different app versions.
///
/// This registry allows defining specific migration functions that are only
/// applied when needed based on semantic version comparison.
class MigrationRegistry {
  final List<MigrationStep> _migrationSteps = [];

  /// Registers a migration step from one version to another.
  void registerMigration({
    required String fromVersion,
    required String toVersion,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic> data) migrationFunction,
    required String description,
  }) {
    final fromSemVer = SemanticVersion.parse(fromVersion);
    final toSemVer = SemanticVersion.parse(toVersion);

    _migrationSteps.add(MigrationStep(
      fromVersion: fromSemVer,
      toVersion: toSemVer,
      migrationFunction: migrationFunction,
      description: description,
    ));

    // Keep migrations sorted by fromVersion for efficient processing
    _migrationSteps.sort((a, b) => a.fromVersion.compareTo(b.fromVersion));
  }

  /// Gets all migration steps needed to migrate from source version to target version.
  ///
  /// Returns a list of migration steps that need to be applied in sequence.
  /// If no migrations are needed, returns an empty list.
  List<MigrationStep> getMigrationPath(SemanticVersion sourceVersion, SemanticVersion targetVersion) {
    // If source version is same or newer than target, no migration needed
    if (sourceVersion >= targetVersion) {
      return [];
    }

    final requiredMigrations = <MigrationStep>[];
    SemanticVersion currentVersion = sourceVersion;

    // Find migration steps that need to be applied
    while (currentVersion < targetVersion) {
      final nextMigration = _findNextMigration(currentVersion, targetVersion);

      if (nextMigration == null) {
        // No more migrations available, but we haven't reached target version
        // This is okay - it means no specific migrations are defined for this version range
        break;
      }

      requiredMigrations.add(nextMigration);
      currentVersion = nextMigration.toVersion;
    }

    return requiredMigrations;
  }

  /// Finds the next applicable migration step from the current version.
  MigrationStep? _findNextMigration(SemanticVersion currentVersion, SemanticVersion targetVersion) {
    return _migrationSteps
            .where((step) => step.fromVersion == currentVersion && step.toVersion <= targetVersion)
            .isNotEmpty
        ? _migrationSteps.where((step) => step.fromVersion == currentVersion && step.toVersion <= targetVersion).first
        : null;
  }

  /// Checks if any migrations are needed between two versions.
  bool isMigrationNeeded(SemanticVersion sourceVersion, SemanticVersion targetVersion) {
    return getMigrationPath(sourceVersion, targetVersion).isNotEmpty;
  }

  /// Gets all registered migration steps for debugging purposes.
  List<MigrationStep> get registeredMigrations => List.unmodifiable(_migrationSteps);

  /// Clears all registered migrations. Primarily for testing.
  void clear() {
    _migrationSteps.clear();
  }
}
