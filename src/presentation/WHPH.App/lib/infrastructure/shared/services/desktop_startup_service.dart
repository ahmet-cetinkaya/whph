import 'dart:io';
import 'package:whph/presentation/ui/shared/constants/app_args.dart';

/// Service to handle desktop application startup behavior
class DesktopStartupService {
  static bool _startMinimized = false;
  static bool _startSync = false;
  static List<String> _mainArgs = [];

  /// Initialize with direct arguments from main()
  static void initializeWithArgs(List<String> args) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    _mainArgs = args;
    _startMinimized = args.contains(AppArgs.minimized);
    _startSync = args.contains(AppArgs.sync);
  }

  /// Check if the application should start minimized
  static bool get shouldStartMinimized => _startMinimized;

  /// Check if the application should only trigger sync
  static bool get shouldStartSync => _startSync;

  /// Get all startup-related arguments from command line
  static List<String> getStartupArguments() {
    final args = <String>[];
    if (_startMinimized) args.add(AppArgs.minimized);
    if (_startSync) args.add(AppArgs.sync);
    return args;
  }

  /// Check if a specific startup argument is present
  static bool hasArgument(String argument) {
    return _mainArgs.contains(argument);
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
      return 'Starting normally (main args: ${_mainArgs.join(', ')})';
    }
  }
}
