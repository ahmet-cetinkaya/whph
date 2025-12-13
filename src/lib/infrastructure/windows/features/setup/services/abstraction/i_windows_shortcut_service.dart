/// Service for managing Windows shortcuts
abstract class IWindowsShortcutService {
  /// Create a shortcut in the Start Menu
  Future<void> createStartMenuShortcut({
    required String appName,
    required String target,
    required String iconPath,
    String? description,
  });

  /// Create a Windows shortcut (.lnk file)
  Future<void> createShortcut({
    required String target,
    required String shortcutPath,
    required String iconPath,
    String? description,
  });
}
