import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/task_settings.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';

class TasksTile extends StatelessWidget {
  const TasksTile({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        return SettingsMenuTile(
          title: translationService.translate(SettingsTranslationKeys.taskPreferencesTitle),
          subtitle: translationService.translate(SettingsTranslationKeys.taskPreferencesDescription),
          icon: Icons.task_alt,
          isActive: true,
          onTap: () {
            ResponsiveDialogHelper.showResponsiveDialog(
              context: context,
              child: const TaskSettings(),
              size: DialogSize.large,
            );
          },
        );
      },
    );
  }
}
