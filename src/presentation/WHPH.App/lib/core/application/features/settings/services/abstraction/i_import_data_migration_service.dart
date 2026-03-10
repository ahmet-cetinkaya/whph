/// Abstract interface for import data migration service.
///
/// This service handles version-specific transformations for imported data,
/// ensuring backward compatibility when importing data from older app versions.
abstract class IImportDataMigrationService {
  /// Migrates imported data from the source version to the current app version.
  ///
  /// [data] - The imported data as a Map
  /// [sourceVersion] - The version of the app that exported this data
  ///
  /// Returns the migrated data compatible with the current app version
  Future<Map<String, dynamic>> migrateData(Map<String, dynamic> data, String sourceVersion);

  /// Checks if migration is needed from the source version to current version.
  ///
  /// [sourceVersion] - The version of the app that exported the data
  ///
  /// Returns true if migration is needed, false otherwise
  bool isMigrationNeeded(String sourceVersion);

  /// Gets the list of available migration versions.
  ///
  /// Returns a list of version strings that have migrations available
  List<String> getAvailableMigrationVersions();
}
