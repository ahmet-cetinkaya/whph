import 'dart:io';
import '../../../shared/features/window/window_manager.dart';

/// Linux-specific implementation of WindowManagerInterface
class LinuxWindowManager extends WindowManager {
  /// Path to the focus window script
  final String _scriptPath;

  /// Constructor
  LinuxWindowManager({String? scriptPath}) : _scriptPath = scriptPath ?? 'linux/focus_window.sh';

  @override
  Future<void> focus() async {
    // Get the current window title
    final currentTitle = await getTitle();

    // Try to focus using base implementation first
    await super.focus();

    bool isFocused = await super.isFocused();
    if (!isFocused && File(_scriptPath).existsSync()) {
      // Some desktop environments require a script to focus the window
      await Process.run('chmod', ['+x', _scriptPath]);
      await Process.run(_scriptPath, [currentTitle]);
    }
  }
}
