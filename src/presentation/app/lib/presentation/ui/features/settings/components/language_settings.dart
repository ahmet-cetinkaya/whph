import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/shared/components/language_select_dialog.dart';

class LanguageSettings extends StatelessWidget {
  LanguageSettings({super.key}) : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showLanguageDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: LanguageSelectDialog(
        onLanguageChanged: (languageCode) {
          _translationService.changeLanguage(context, languageCode);
          Navigator.pop(context);
          Navigator.of(context).pushReplacementNamed(SettingsPage.route);
        },
      ),
      size: DialogSize.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguageCode = _translationService.getCurrentLanguage(context);
    return SettingsMenuTile(
      icon: Icons.language,
      title: _translationService.translate(SettingsTranslationKeys.languageTitle),
      subtitle: currentLanguageCode,
      onTap: () => _showLanguageDialog(context),
      isActive: true,
    );
  }
}
