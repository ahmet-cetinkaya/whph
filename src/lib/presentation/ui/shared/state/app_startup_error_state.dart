import 'package:flutter/foundation.dart';

/// Manages the global state for app startup errors
class AppStartupErrorState extends ChangeNotifier {
  static final AppStartupErrorState _instance = AppStartupErrorState._internal();
  factory AppStartupErrorState() => _instance;
  AppStartupErrorState._internal();

  Object? _startupError;
  StackTrace? _startupStackTrace;
  bool _hasStartupError = false;

  /// Whether a startup error has occurred
  bool get hasStartupError => _hasStartupError;

  /// The startup error object
  Object? get startupError => _startupError;

  /// The startup error stack trace
  StackTrace? get startupStackTrace => _startupStackTrace;

  /// Sets a startup error
  void setStartupError(Object error, [StackTrace? stackTrace]) {
    _hasStartupError = true;
    _startupError = error;
    _startupStackTrace = stackTrace;
    notifyListeners();
  }

  /// Clears the startup error state
  void clearStartupError() {
    _hasStartupError = false;
    _startupError = null;
    _startupStackTrace = null;
    notifyListeners();
  }

  /// Gets a formatted error message for display
  String getFormattedErrorMessage() {
    if (_startupError == null) return 'Unknown startup error';
    return _startupError.toString();
  }

  /// Gets detailed error information for reporting
  String getDetailedErrorInfo() {
    final buffer = StringBuffer();
    buffer.writeln('Startup Error:');
    buffer.writeln(_startupError?.toString() ?? 'Unknown error');
    if (_startupStackTrace != null) {
      buffer.writeln('\nStack Trace:');
      buffer.writeln(_startupStackTrace.toString());
    }
    return buffer.toString();
  }
}
