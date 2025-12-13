/// Interface for Linux desktop file and icon operations.
abstract class ILinuxDesktopService {
  /// Update desktop file with correct paths.
  Future<void> updateDesktopFile(String filePath, String iconPath, String appDir);

  /// Update icon cache after installing icons.
  Future<void> updateIconCache(String sharePath);

  /// Install system icon to user's icon directory.
  Future<void> installSystemIcon(String sourceIcon);
}
