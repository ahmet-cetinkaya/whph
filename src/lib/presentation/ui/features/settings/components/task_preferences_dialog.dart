import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/task_settings.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class TaskPreferencesDialog extends StatelessWidget {
  const TaskPreferencesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            title: Text(
              translationService.translate(SettingsTranslationKeys.taskSettingsTitle),
            ),
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: translationService.translate(SharedTranslationKeys.backButton),
            ),
            automaticallyImplyLeading: false,
            actions: const [
              SizedBox(width: AppTheme.sizeSmall),
            ],
          ),
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.sizeMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8.0,
                  children: [
                    // Task Settings
                    const TaskSettings(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
