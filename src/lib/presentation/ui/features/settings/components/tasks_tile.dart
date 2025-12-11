import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/task_preferences_dialog.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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
          elevation: 0,
          color: AppTheme.surface1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sizeMedium,
              vertical: AppTheme.sizeSmall,
            ),
            leading: StyledIcon(
              Icons.task_alt,
              isActive: true,
            ),
            title: Text(
              translationService.translate(SettingsTranslationKeys.taskPreferencesTitle),
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              translationService.translate(SettingsTranslationKeys.taskPreferencesDescription),
              style: AppTheme.bodySmall,
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
