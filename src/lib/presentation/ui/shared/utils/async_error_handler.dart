import 'package:flutter/material.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Consistent error handling for async operations across the codebase
class AsyncErrorHandler {
  /// Executes an async operation with error handling, optional success/error callbacks,
  /// and automatic error display via [ErrorHelper].
  static Future<T?> execute<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
    bool checkMounted = true,
    NotificationPosition errorPosition = NotificationPosition.bottom,
  }) async {
    try {
      final result = await operation();

      if (checkMounted && !context.mounted) return null;

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } on BusinessException catch (e) {
      if (!checkMounted || context.mounted) {
        ErrorHelper.showError(context, e, position: errorPosition);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      Logger.error('$e');
      Logger.error('Stack trace: $stackTrace');

      if (!checkMounted || context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage,
          position: errorPosition,
        );
      }

      if (onError != null) {
        onError(e);
      }
    } finally {
      if (finallyAction != null) {
        finallyAction();
      }
    }

    return null;
  }

  /// Same as [execute] but for void operations (no return value).
  static Future<void> executeVoid({
    required BuildContext context,
    required Future<void> Function() operation,
    VoidCallback? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
    bool checkMounted = true,
    NotificationPosition errorPosition = NotificationPosition.bottom,
  }) async {
    try {
      await operation();

      if (checkMounted && !context.mounted) return;

      if (onSuccess != null) {
        onSuccess();
      }
    } on BusinessException catch (e) {
      if (!checkMounted || context.mounted) {
        ErrorHelper.showError(context, e, position: errorPosition);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      Logger.error('$e');
      Logger.error('Stack trace: $stackTrace');

      if (!checkMounted || context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage,
          position: errorPosition,
        );
      }

      if (onError != null) {
        onError(e);
      }
    } finally {
      if (finallyAction != null) {
        finallyAction();
      }
    }
  }

  /// Executes an async operation with a loading state toggle.
  /// Sets [setLoading](true) before and (false) after the operation.
  static Future<T?> executeWithLoading<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required Function(bool isLoading) setLoading,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
    NotificationPosition errorPosition = NotificationPosition.bottom,
  }) async {
    setLoading(true);

    try {
      final result = await operation();

      if (!context.mounted) return null;

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } on BusinessException catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e, position: errorPosition);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      Logger.error('$e');
      Logger.error('Stack trace: $stackTrace');

      if (context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage,
          position: errorPosition,
        );
      }

      if (onError != null) {
        onError(e);
      }
    } finally {
      if (context.mounted) {
        setLoading(false);
      }

      if (finallyAction != null && context.mounted) {
        finallyAction();
      }
    }

    return null;
  }

  /// Chains async operations while checking context.mounted between each step.
  static Future<T?> executeChain<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String errorMessage,
    List<Function(BuildContext context)>? intermediateContextChecks,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    NotificationPosition errorPosition = NotificationPosition.bottom,
  }) async {
    if (!context.mounted) return null;

    return await execute<T>(
      context: context,
      errorMessage: errorMessage,
      operation: () async {
        final result = await operation();

        if (intermediateContextChecks != null) {
          for (var check in intermediateContextChecks) {
            if (!context.mounted) return result;
            check(context);
          }
        }

        return result;
      },
      onSuccess: onSuccess,
      onError: onError,
      finallyAction: finallyAction,
      errorPosition: errorPosition,
    );
  }
}
