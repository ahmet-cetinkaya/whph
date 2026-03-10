/// Interface for Linux application update operations.
abstract class ILinuxUpdateService {
  /// Download and install an update from the given URL.
  Future<void> downloadAndInstallUpdate(String downloadUrl);

  /// Get the current application version.
  Future<String> getAppVersion();
}
