import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/task_preferences_dialog.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';

class TasksTile extends StatelessWidget {
  const TasksTile({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.task_alt,
            ),
            title: Text(
              translationService.translate(SettingsTranslationKeys.taskPreferencesTitle),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              translationService.translate(SettingsTranslationKeys.taskPreferencesDescription),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 16,
            ),
            onTap: () {
              ResponsiveDialogHelper.showResponsiveDialog(
                context: context,
                child: const TaskPreferencesDialog(),
                size: DialogSize.large,
              );
            },
          ),
        );
      },
    );
  }
}
