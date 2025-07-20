import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class LanguageSettings extends StatelessWidget {
  LanguageSettings({super.key}) : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showLanguageDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: _LanguageDialog(),
      size: DialogSize.medium,
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

class _LanguageOption {
  final String code;
  final String displayName;

  const _LanguageOption({
    required this.code,
    required this.displayName,
  });
}

class _LanguageDialog extends StatelessWidget {
  final ITranslationService _translationService;

  _LanguageDialog() : _translationService = container.resolve<ITranslationService>();

  static const List<_LanguageOption> _supportedLanguages = [
    _LanguageOption(code: 'en', displayName: 'English'),
    _LanguageOption(code: 'tr', displayName: 'Türkçe'),
    _LanguageOption(code: 'de', displayName: 'Deutsch'),
    _LanguageOption(code: 'fr', displayName: 'Français'),
    _LanguageOption(code: 'es', displayName: 'Español'),
    _LanguageOption(code: 'ru', displayName: 'Русский'),
    _LanguageOption(code: 'it', displayName: 'Italiano'),
    _LanguageOption(code: 'ja', displayName: '日本語'),
    _LanguageOption(code: 'ko', displayName: '한국어'),
    _LanguageOption(code: 'zh', displayName: '中文'),
  ];

  void _changeLanguage(BuildContext context, String languageCode) {
    _translationService.changeLanguage(context, languageCode);
    Navigator.pop(context);
    Navigator.of(context).pushReplacementNamed(SettingsPage.route);
  }

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
        child: ListView(
          children: [
            // Language Options Section
            for (final language in _supportedLanguages)
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(
                  language.displayName,
                  style: AppTheme.bodyMedium,
                ),
                trailing: _translationService.getCurrentLanguage(context) == language.code
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => _changeLanguage(context, language.code),
              ),
          ],
        ),
      ),
    );
  }
}
