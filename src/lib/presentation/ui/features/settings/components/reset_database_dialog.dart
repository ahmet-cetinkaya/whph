import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/restart_screen.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class ResetDatabaseDialog extends StatelessWidget {
  const ResetDatabaseDialog({super.key});

  Future<void> _handleReset(BuildContext context) async {
    // Navigate to restart screen immediately
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestartScreen()),
        (route) => false,
      );
    }

    // Small delay to allow UI to update
    await Future.delayed(const Duration(milliseconds: 500));

    // Perform reset
    await AppDatabase.instance().resetDatabase();
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
              SwipeToConfirm(
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
