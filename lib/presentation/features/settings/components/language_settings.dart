import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';

class LanguageSettings extends StatelessWidget {
  LanguageSettings({super.key}) : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _LanguageBottomSheet(),
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
        onTap: () => _showLanguageBottomSheet(context),
      ),
    );
  }
}

class _LanguageBottomSheet extends StatelessWidget {
  _LanguageBottomSheet() : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(
              _translationService.translate(SettingsTranslationKeys.languageEnglish),
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
            title: Text(
              _translationService.translate(SettingsTranslationKeys.languageTurkish),
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
    );
  }
}
