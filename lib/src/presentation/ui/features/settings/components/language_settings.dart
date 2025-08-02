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
  final String englishName;

  const _LanguageOption({
    required this.code,
    required this.displayName,
    required this.englishName,
  });
}

class _LanguageSection {
  final String title;
  final List<_LanguageOption> languages;

  const _LanguageSection({
    required this.title,
    required this.languages,
  });
}

class _LanguageDialog extends StatelessWidget {
  final ITranslationService _translationService;

  _LanguageDialog() : _translationService = container.resolve<ITranslationService>();

  static const List<_LanguageSection> _languageSections = [
    _LanguageSection(
      title: 'Western Europe',
      languages: [
        _LanguageOption(code: 'en', displayName: 'English', englishName: 'English'),
        _LanguageOption(code: 'de', displayName: 'Deutsch', englishName: 'German'),
        _LanguageOption(code: 'es', displayName: 'Español', englishName: 'Spanish'),
        _LanguageOption(code: 'fr', displayName: 'Français', englishName: 'French'),
        _LanguageOption(code: 'it', displayName: 'Italiano', englishName: 'Italian'),
        _LanguageOption(code: 'nl', displayName: 'Nederlands', englishName: 'Dutch'),
        _LanguageOption(code: 'pt', displayName: 'Português', englishName: 'Portuguese'),
      ],
    ),
    _LanguageSection(
      title: 'Northern Europe',
      languages: [
        _LanguageOption(code: 'da', displayName: 'Dansk', englishName: 'Danish'),
        _LanguageOption(code: 'fi', displayName: 'Suomi', englishName: 'Finnish'),
        _LanguageOption(code: 'no', displayName: 'Norsk', englishName: 'Norwegian'),
        _LanguageOption(code: 'sv', displayName: 'Svenska', englishName: 'Swedish'),
      ],
    ),
    _LanguageSection(
      title: 'Central Europe',
      languages: [
        _LanguageOption(code: 'cs', displayName: 'Čeština', englishName: 'Czech'),
        _LanguageOption(code: 'pl', displayName: 'Polski', englishName: 'Polish'),
        _LanguageOption(code: 'sl', displayName: 'Slovenščina', englishName: 'Slovenian'),
      ],
    ),
    _LanguageSection(
      title: 'Eastern Europe',
      languages: [
        _LanguageOption(code: 'ro', displayName: 'Română', englishName: 'Romanian'),
        _LanguageOption(code: 'ru', displayName: 'Русский', englishName: 'Russian'),
        _LanguageOption(code: 'uk', displayName: 'Українська', englishName: 'Ukrainian'),
      ],
    ),
    _LanguageSection(
      title: 'Southern Europe',
      languages: [
        _LanguageOption(code: 'el', displayName: 'Ελληνικά', englishName: 'Greek'),
        _LanguageOption(code: 'tr', displayName: 'Türkçe', englishName: 'Turkish'),
      ],
    ),
    _LanguageSection(
      title: 'Asia',
      languages: [
        _LanguageOption(code: 'ja', displayName: '日本語', englishName: 'Japanese'),
        _LanguageOption(code: 'ko', displayName: '한국어', englishName: 'Korean'),
        _LanguageOption(code: 'zh', displayName: '中文', englishName: 'Chinese'),
      ],
    ),
  ];

  void _changeLanguage(BuildContext context, String languageCode) {
    _translationService.changeLanguage(context, languageCode);
    Navigator.pop(context);
    Navigator.of(context).pushReplacementNamed(SettingsPage.route);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.sizeMedium,
        right: AppTheme.sizeMedium,
        top: AppTheme.sizeLarge,
        bottom: AppTheme.sizeSmall,
      ),
      child: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, _LanguageOption language) {
    final isSelected = _translationService.getCurrentLanguage(context) == language.code;
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.sizeMedium,
        vertical: AppTheme.sizeXSmall,
      ),
      elevation: isSelected ? 4 : 1,
      child: ListTile(
        leading: Icon(
          Icons.language,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
        title: Text(
          language.displayName,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          language.englishName,
          style: AppTheme.bodySmall.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _changeLanguage(context, language.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          _translationService.translate(SettingsTranslationKeys.languageChooseTitle),
        ),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppTheme.sizeSmall),
          
          // Language count info
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.sizeMedium),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Expanded(
                      child: Text(
                        '22 languages available',
                        style: AppTheme.bodySmall.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Language sections
          for (final section in _languageSections) ...[
            _buildSectionHeader(section.title),
            for (final language in section.languages)
              _buildLanguageTile(context, language),
          ],
          
          const SizedBox(height: AppTheme.sizeLarge),
        ],
      ),
    );
  }
}