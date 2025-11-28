import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/components/debug_logs_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/tasks_tile.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';

class AdvancedSettingsDialog extends StatelessWidget {
  const AdvancedSettingsDialog({super.key});

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
            title: Text(
              translationService.translate(SettingsTranslationKeys.advancedSettingsTitle),
            ),
            elevation: 0,
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
                    // Tasks Settings
                    const TasksTile(),

                    // Debug Logs Settings
                    const DebugLogsSettings(),
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
