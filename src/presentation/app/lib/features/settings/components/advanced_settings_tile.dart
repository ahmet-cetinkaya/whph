import 'package:flutter/material.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/features/settings/components/advanced_settings_dialog.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/components/settings_menu_tile.dart';

class AdvancedSettingsTile extends StatelessWidget {
  const AdvancedSettingsTile({super.key});

  void _showAdvancedSettings(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const AdvancedSettingsDialog(),
      size: DialogSize.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        return SettingsMenuTile(
          icon: Icons.settings_applications,
          title: translationService.translate(SettingsTranslationKeys.advancedSettingsTitle),
          subtitle: translationService.translate(SettingsTranslationKeys.advancedSettingsDescription),
          onTap: () => _showAdvancedSettings(context),
          isActive: true,
        );
      },
    );
  }
}
