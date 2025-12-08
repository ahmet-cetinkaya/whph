import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';

class LanguageSettings extends StatelessWidget {
  LanguageSettings({super.key}) : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showLanguageDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: _LanguageDialog(),
      size: DialogSize.large,
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

class _StyledLanguageCode extends StatelessWidget {
  final String languageCode;
  final bool isActive;

  const _StyledLanguageCode({
    required this.languageCode,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40, // Match StyledIcon size (24 + 8*2 padding = 40)
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : AppTheme.surface2,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        languageCode.toUpperCase(),
        style: AppTheme.labelLarge.copyWith(
          color: isActive ? theme.colorScheme.primary : AppTheme.textColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
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

  Widget _buildLanguageTile(BuildContext context, _LanguageOption language) {
    final isSelected = _translationService.getCurrentLanguage(context) == language.code;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.sizeMedium,
        vertical: AppTheme.sizeXSmall,
      ),
      elevation: isSelected ? 4 : 1,
      child: ListTile(
        leading: _StyledLanguageCode(
          languageCode: language.code,
          isActive: isSelected,
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
            : Icon(
                Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
        onTap: () => _changeLanguage(context, language.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            child: InformationCard.themed(
              context: context,
              icon: Icons.info_outline,
              text: '22 languages available',
            ),
          ),

          // Language sections
          for (final section in _languageSections) ...[
            SectionHeader(
              title: section.title,
              padding: const EdgeInsets.only(
                left: AppTheme.sizeLarge,
                top: AppTheme.sizeLarge,
                bottom: AppTheme.sizeSmall,
              ),
            ),
            for (final language in section.languages) _buildLanguageTile(context, language),
          ],

          const SizedBox(height: AppTheme.sizeLarge),
        ],
      ),
    );
  }
}
