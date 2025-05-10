import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

/// A utility class that provides methods to handle asynchronous operations with error handling.
///
/// This class helps reduce repetitive try-catch blocks throughout the codebase by
/// providing a consistent way to execute async operations and handle errors.
class AsyncErrorHandler {
  /// Executes an asynchronous operation and handles any errors that occur.
  ///
  /// - [context] - The BuildContext used for showing error messages
  /// - [operation] - The async operation to execute
  /// - [onSuccess] - Optional callback for successful operation
  /// - [onError] - Optional callback for handling errors
  /// - [finallyAction] - Optional callback that runs regardless of success or failure
  /// - [errorMessage] - Custom error message for unexpected errors
  /// - [checkMounted] - Whether to check if the widget is still mounted before showing errors
  static Future<T?> execute<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
    bool checkMounted = true,
  }) async {
    try {
      final result = await operation();

      // Only proceed if widget is still mounted when requested
      if (checkMounted && !context.mounted) return null;

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } on BusinessException catch (e) {
      if (!checkMounted || context.mounted) {
        ErrorHelper.showError(context, e);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ERROR: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      if (!checkMounted || context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage ?? 'An unexpected error occurred.',
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

  /// Executes an asynchronous operation that doesn't return a result and handles any errors.
  ///
  /// - [context] - The BuildContext used for showing error messages
  /// - [operation] - The async operation to execute
  /// - [onSuccess] - Optional callback for successful operation
  /// - [onError] - Optional callback for handling errors
  /// - [finallyAction] - Optional callback that runs regardless of success or failure
  /// - [errorMessage] - Custom error message for unexpected errors
  /// - [checkMounted] - Whether to check if the widget is still mounted before showing errors
  static Future<void> executeVoid({
    required BuildContext context,
    required Future<void> Function() operation,
    VoidCallback? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
    bool checkMounted = true,
  }) async {
    try {
      await operation();

      // Only proceed if widget is still mounted when requested
      if (checkMounted && !context.mounted) return;

      if (onSuccess != null) {
        onSuccess();
      }
    } on BusinessException catch (e) {
      if (!checkMounted || context.mounted) {
        ErrorHelper.showError(context, e);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ERROR: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      if (!checkMounted || context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage ?? 'An unexpected error occurred.',
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

  /// Executes an asynchronous operation with the setState pattern common in StatefulWidget components.
  ///
  /// This method handles the common pattern of setting a loading state before the operation
  /// and resetting it after completion, while properly handling errors.
  ///
  /// - [context] - The BuildContext used for showing error messages
  /// - [operation] - The async operation to execute
  /// - [setLoading] - Function to set the loading state
  /// - [onSuccess] - Optional callback for successful operation
  /// - [onError] - Optional callback for handling errors
  /// - [finallyAction] - Optional callback that runs regardless of success or failure (after setLoading(false))
  /// - [errorMessage] - Custom error message for unexpected errors
  static Future<T?> executeWithLoading<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required Function(bool isLoading) setLoading,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
    String? errorMessage,
  }) async {
    setLoading(true);

    try {
      final result = await operation();

      // Only proceed if widget is still mounted
      if (!context.mounted) return null;

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } on BusinessException catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
      if (onError != null) {
        onError(e);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ERROR: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      if (context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e is Exception ? e : Exception(e.toString()),
          stackTrace,
          message: errorMessage ?? 'An unexpected error occurred.',
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

  /// Executes a chain of async operations that depend on BuildContext, ensuring proper mounted checks.
  ///
  /// This is particularly useful for scenarios where you need to perform multiple async operations
  /// in sequence while checking context.mounted between each step.
  static Future<T?> executeChain<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String errorMessage,
    List<Function(BuildContext context)>? intermediateContextChecks,
    Function(T result)? onSuccess,
    Function(Object error)? onError,
    VoidCallback? finallyAction,
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
    );
  }
}
