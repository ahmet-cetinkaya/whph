import 'package:flutter/material.dart';
import 'package:whph/features/settings/components/habit_settings.dart';
import 'package:whph/features/settings/components/settings_menu_tile.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:acore/utils/dialog_size.dart';

class HabitsTile extends StatelessWidget {
  const HabitsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return SettingsMenuTile(
      title: translationService.translate(SettingsTranslationKeys.habitSettingsTitle),
      subtitle: translationService.translate(SettingsTranslationKeys.habitSettingsDescription),
      icon: Icons.calendar_today,
      isActive: true,
      onTap: () {
        ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          child: const HabitSettings(),
          size: DialogSize.large,
        );
      },
    );
  }
}
