/// Service for managing Windows application updates
abstract class IWindowsUpdateService {
  /// Download and install a Windows update
  ///
  /// Supports both portable (ZIP) and installer (EXE) update packages
  /// - Portable updates: Extract and replace application files
  /// - Installer updates: Run installer with silent flag
  ///
  /// Application will be restarted after update
  Future<void> downloadAndInstallUpdate(String downloadUrl);
}
