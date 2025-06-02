import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class LanguageSettings extends StatelessWidget {
  LanguageSettings({super.key}) : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showLanguageDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: _LanguageDialog(),
      size: DialogSize.small,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(
          _translationService.translate(SettingsTranslationKeys.languageTitle),
          style: AppTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge),
        onTap: () => _showLanguageDialog(context),
      ),
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  final ITranslationService _translationService;

  _LanguageDialog() : _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(SettingsTranslationKeys.languageChooseTitle),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Options Section
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text(
                'English',
                style: AppTheme.bodyMedium,
              ),
              trailing: _translationService.getCurrentLanguage(context) == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _translationService.changeLanguage(context, 'en');
                Navigator.pop(context);
                Navigator.of(context).pushReplacementNamed(SettingsPage.route);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text(
                'Türkçe',
                style: AppTheme.bodyMedium,
              ),
              trailing: _translationService.getCurrentLanguage(context) == 'tr'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _translationService.changeLanguage(context, 'tr');
                Navigator.pop(context);
                Navigator.of(context).pushReplacementNamed(SettingsPage.route);
              },
            ),
          ],
        ),
      ),
    );
  }
}
