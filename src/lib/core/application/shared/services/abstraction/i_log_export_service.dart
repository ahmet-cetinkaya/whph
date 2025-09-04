/// Service for exporting log files to user-selected locations
abstract class ILogExportService {
  /// Exports the log file to a user-selected location
  ///
  /// Returns the path where the file was saved, or null if the export was cancelled
  Future<String?> exportLogFile(String logFilePath);
}
