import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/restart_screen.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class ResetDatabaseDialog extends StatefulWidget {
  const ResetDatabaseDialog({super.key});

  @override
  State<ResetDatabaseDialog> createState() => _ResetDatabaseDialogState();
}

class _ResetDatabaseDialogState extends State<ResetDatabaseDialog> {
  bool _isResetting = false;

  Future<void> _handleReset(BuildContext context) async {
    setState(() {
      _isResetting = true;
    });

    try {
      // Perform reset first
      await AppDatabase.instance().resetDatabase();

      // Only navigate on success
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RestartScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Reset loading state on error
      if (context.mounted) {
        setState(() {
          _isResetting = false;
        });

        // Show error dialog
        _showErrorDialog(context, e);
      }
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final translationService = container.resolve<ITranslationService>();

    // Log the actual error for debugging
    Logger.error('Database reset failed: ${error.toString()}');

    if (error is FileSystemException) {
      if (error.osError?.errorCode == 13 || error.message.contains('Permission denied')) {
        return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorPermissionDenied);
      } else if (error.osError?.errorCode == 28 || error.message.contains('No space left')) {
        return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorDiskFull);
      } else if (error.message.contains('Database file not found')) {
        return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorFileNotFound);
      }
      return '${translationService.translate(SettingsTranslationKeys.resetDatabaseErrorFileAccess)}: ${error.message}';
    } else if (error.toString().contains('database is locked')) {
      return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorDatabaseLocked);
    } else if (error.toString().contains('Sqlite') || error.toString().contains('SQL')) {
      return '${translationService.translate(SettingsTranslationKeys.resetDatabaseErrorSqlite)}: ${error.toString()}';
    } else if (error is StateError) {
      return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorStateError);
    } else if (error.toString().contains('timeout') || error.toString().contains('Timeout')) {
      return translationService.translate(SettingsTranslationKeys.resetDatabaseErrorTimeout);
    } else {
      return '${translationService.translate(SettingsTranslationKeys.resetDatabaseErrorMessage)}: ${error.toString()}';
    }
  }

  void _showErrorDialog(BuildContext context, dynamic error) {
    final translationService = container.resolve<ITranslationService>();
    final userMessage = _getUserFriendlyErrorMessage(error);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          translationService.translate(SettingsTranslationKeys.resetDatabaseErrorTitle),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userMessage),
            const SizedBox(height: 16),
            Text(
              translationService.translate(SettingsTranslationKeys.resetDatabaseErrorHelpText),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              translationService.translate(SettingsTranslationKeys.resetDatabaseErrorCancel),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleReset(context);
            },
            child: Text(
              translationService.translate(SettingsTranslationKeys.resetDatabaseErrorRetry),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          translationService.translate(SettingsTranslationKeys.resetDatabaseDialogTitle),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.sizeXLarge),
              Icon(
                Icons.warning_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppTheme.sizeLarge),
              Text(
                translationService.translate(SettingsTranslationKeys.resetDatabaseDialogWarning),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sizeXLarge),
              _isResetting
                  ? Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppTheme.sizeLarge),
                        Text(
                          translationService.translate(SettingsTranslationKeys.resetDatabaseDialogResetting),
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : SwipeToConfirm(
                      text: translationService.translate(SettingsTranslationKeys.resetDatabaseDialogConfirmText),
                      onConfirmed: () => _handleReset(context),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      sliderColor: theme.colorScheme.error,
                      iconColor: theme.colorScheme.onError,
                    ),
              const SizedBox(height: AppTheme.sizeLarge),
            ],
          ),
        ),
      ),
    );
  }
}
