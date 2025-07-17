import 'dart:io';

/// Service for managing application directory paths across different platforms
abstract class IApplicationDirectoryService {
  /// Gets the standard application directory for the current platform
  /// 
  /// Returns:
  /// - Windows: %APPDATA%\whph\
  /// - Linux: ~/.local/share/whph/
  /// - Android: Application support directory with whph subfolder
  Future<Directory> getApplicationDirectory();
}