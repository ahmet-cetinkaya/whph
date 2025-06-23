import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/shared/utils/error_helper.dart';

/// Service responsible for handling global errors and exceptions
class GlobalErrorHandler {
  /// Handle uncaught exceptions with proper context checking
  static void handleGlobalError(
    Object error,
    StackTrace stack,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final context = navigatorKey.currentContext;

    if (context != null) {
      _handleErrorWithContext(error, stack, context);
    } else {
      _handleErrorWithoutContext(error, stack);
    }
  }

  /// Handle error when context is available
  static void _handleErrorWithContext(
    Object error,
    StackTrace stack,
    BuildContext context,
  ) {
    try {
      final overlay = Overlay.maybeOf(context);

      if (overlay != null) {
        _showErrorNotification(error, stack, context);
      } else {
        _logErrorOnly(error, stack);
      }
    } catch (e) {
      _logErrorOnly(error, stack);
    }
  }

  /// Handle error when context is not available
  static void _handleErrorWithoutContext(Object error, StackTrace stack) {
    if (kDebugMode) {
      Logger.error('Error occurred with no context available: $error');
      Logger.error('Stack trace: $stack');
    }
  }

  /// Show error notification to user
  static void _showErrorNotification(
    Object error,
    StackTrace stack,
    BuildContext context,
  ) {
    if (error is BusinessException) {
      ErrorHelper.showError(context, error);
    } else {
      ErrorHelper.showUnexpectedError(
        context,
        error,
        stack,
      );
    }
  }

  /// Log error without showing notification
  static void _logErrorOnly(Object error, StackTrace stack) {
    if (kDebugMode) {
      Logger.error('Error displaying error notification: $error');
      Logger.error('Stack trace: $stack');
    }
  }
}
