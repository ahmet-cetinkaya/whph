import 'dart:io';

/// Service to get native arguments that were passed to the application
class NativeArgsService {
  static List<String> _cachedArgs = [];
  static bool _initialized = false;
  
  /// Get the arguments that were passed to the native application
  static List<String> getArgs() {
    if (!_initialized) {
      _initialize();
      _initialized = true;
    }
    return _cachedArgs;
  }
  
  static void _initialize() {
    // Try multiple sources for getting the arguments
    _cachedArgs = [];
    
    // Method 1: Platform.executableArguments (may not work for desktop)
    _cachedArgs.addAll(Platform.executableArguments);
    
    // Method 2: Environment variables
    final envArgs = Platform.environment['FLUTTER_ARGS'];
    if (envArgs != null) {
      _cachedArgs.addAll(envArgs.split(' '));
    }
    
    // Method 3: Dart VM arguments (for Flutter desktop apps)
    // The native side passes args through dart entrypoint, but we need to access them differently
    // For now, we'll rely on the native side handling and just log what we can see
    
    // Remove duplicates and empty strings
    _cachedArgs = _cachedArgs.where((arg) => arg.isNotEmpty).toSet().toList();
  }
  
  /// Check if a specific argument is present
  static bool hasArg(String arg) {
    return getArgs().contains(arg);
  }
  
  /// Check if any of the provided arguments are present
  static bool hasAnyArg(List<String> args) {
    final currentArgs = getArgs();
    return args.any((arg) => currentArgs.contains(arg));
  }
  
  /// Get debug info about available arguments
  static String getDebugInfo() {
    final execArgs = Platform.executableArguments;
    final envVars = Platform.environment.keys.where((k) => k.contains('FLUTTER') || k.contains('DART')).toList();
    
    return '''
Arguments Debug Info:
- Platform.executableArguments: ${execArgs.isEmpty ? 'none' : execArgs.join(', ')}
- Cached args: ${_cachedArgs.isEmpty ? 'none' : _cachedArgs.join(', ')}
- Flutter/Dart env vars: ${envVars.isEmpty ? 'none' : envVars.join(', ')}
''';
  }
}