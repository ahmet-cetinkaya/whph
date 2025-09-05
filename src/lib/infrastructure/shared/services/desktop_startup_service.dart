import 'dart:io';
import 'package:whph/presentation/ui/shared/constants/app_args.dart';
import 'package:whph/infrastructure/shared/services/native_args_service.dart';

/// Service to handle desktop application startup behavior
class DesktopStartupService {
  static bool _startMinimized = false;
  static List<String> _mainArgs = [];

  /// Initialize startup configuration from command line arguments
  static void initialize() {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    // Check command line arguments for minimized startup
    _startMinimized = _checkMinimizedStartup();
  }
  
  /// Initialize with direct arguments from main()
  static void initializeWithArgs(List<String> args) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    
    _mainArgs = args;
    _startMinimized = args.contains(AppArgs.minimized);
  }

  /// Check if the application should start minimized
  static bool get shouldStartMinimized => _startMinimized;

  /// Check command line arguments for minimized startup flags
  static bool _checkMinimizedStartup() {
    // Use NativeArgsService to get arguments from multiple sources
    return NativeArgsService.hasArg(AppArgs.minimized);
  }

  /// Get all startup-related arguments from command line
  static List<String> getStartupArguments() {
    final args = NativeArgsService.getArgs();
    return args.contains(AppArgs.minimized) ? [AppArgs.minimized] : [];
  }

  /// Check if a specific startup argument is present
  static bool hasArgument(String argument) {
    return NativeArgsService.hasArg(argument);
  }

  /// Get startup mode description for debugging
  static String getStartupModeDescription() {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return 'Not a desktop platform';
    }

    if (_startMinimized) {
      final matchingArgs = getStartupArguments();
      return 'Starting minimized (arguments: ${matchingArgs.join(', ')}, main args: ${_mainArgs.join(', ')})';
    } else {
      final debugInfo = NativeArgsService.getDebugInfo();
      return 'Starting normally (main args: ${_mainArgs.join(', ')})\n$debugInfo';
    }
  }
}
