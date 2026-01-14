import 'package:flutter/material.dart';

/// Global context manager for storing app context that has access to Overlay
class ContextManager {
  static BuildContext? _appContext;

  /// Set the app context (should be called from a widget that has Overlay access)
  static void setContext(BuildContext context) {
    _appContext = context;
  }

  /// Get the app context (returns null if not set)
  static BuildContext? get context => _appContext;

  /// Clear the stored context (useful for testing or cleanup)
  static void clearContext() {
    _appContext = null;
  }
}
