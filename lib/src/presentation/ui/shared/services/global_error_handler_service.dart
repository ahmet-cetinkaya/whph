import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';

/// Service responsible for global error handling and error widget configuration
class GlobalErrorHandlerService {
  /// Sets up global error handling for the application
  ///
  /// Configures custom error widgets and zone error handling
  static void setupErrorHandling(GlobalKey<NavigatorState> navigatorKey) {
    if (kDebugMode) {
      debugPrint('GlobalErrorHandlerService: Setting up global error handling...');
    }

    // Configure custom error widget for Flutter rendering errors
    ErrorWidget.builder = _buildErrorWidget;

    if (kDebugMode) {
      debugPrint('GlobalErrorHandlerService: Error handling setup completed');
    }
  }

  /// Handles uncaught exceptions in the application zone
  static void handleZoneError(Object error, StackTrace stack, GlobalKey<NavigatorState> navigatorKey) {
    if (kDebugMode) {
      debugPrint('GlobalErrorHandlerService: Handling zone error: $error');
    }

    if (navigatorKey.currentContext != null) {
      try {
        // Check if overlay is available before trying to show error notifications
        final context = navigatorKey.currentContext!;
        final overlay = Overlay.maybeOf(context);

        if (overlay != null) {
          // Overlay is available, show the error normally
          if (error is BusinessException) {
            ErrorHelper.showError(context, error);
          } else {
            ErrorHelper.showUnexpectedError(
              context,
              error,
              stack,
            );
          }
        } else {
          // Overlay not available, log the error or show fallback
          _logError('Error occurred but overlay not available', error, stack);
        }
      } catch (e) {
        // If error handling itself fails, just log it
        _logError('Error in error handler', e, null);
        _logError('Original error', error, stack);
      }
    } else {
      // No context available, just log the error
      _logError('Error occurred with no context available', error, stack);
    }
  }

  /// Builds a custom error widget for Flutter rendering errors
  static Widget _buildErrorWidget(FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Text(
            ' ${details.exception}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Logs errors in debug mode only
  static void _logError(String message, Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('GlobalErrorHandlerService: $message: $error');
      if (stack != null) {
        debugPrint('Stack trace: $stack');
      }
    }
  }
}
