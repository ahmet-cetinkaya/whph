/// Interface for demo data service
///
/// Provides methods to populate the application with demo data
/// for testing, screenshots, and development purposes.
abstract class IDemoDataService {
  /// Initializes demo data if not already done or if version has changed
  Future<void> initializeDemoDataIfNeeded();

  /// Clears all existing data and populates with fresh demo data
  Future<void> resetDemoData();

  /// Checks if demo data has been initialized and is current version
  Future<bool> isDemoDataInitialized();

  /// Clears all demo data from the database
  Future<void> clearDemoData();

  /// Populates demo data for all entities (tasks, habits, tags, notes, etc.)
  Future<void> populateDemoData();
}
