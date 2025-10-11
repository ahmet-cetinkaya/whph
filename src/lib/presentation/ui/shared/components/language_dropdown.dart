import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class LanguageDropdown extends StatefulWidget {
  final String? initialLanguageCode;
  final ValueChanged<String>? onLanguageChanged;
  final bool showPlaceholder;

  const LanguageDropdown({
    super.key,
    this.initialLanguageCode,
    this.onLanguageChanged,
    this.showPlaceholder = true,
  });

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  late String? _selectedLanguageCode;

  static const List<_LanguageOption> _languageOptions = [
    _LanguageOption(code: 'en', displayName: 'English', nativeName: 'English'),
    _LanguageOption(code: 'de', displayName: 'Deutsch', nativeName: 'Deutsch'),
    _LanguageOption(code: 'es', displayName: 'Español', nativeName: 'Español'),
    _LanguageOption(code: 'fr', displayName: 'Français', nativeName: 'Français'),
    _LanguageOption(code: 'it', displayName: 'Italiano', nativeName: 'Italiano'),
    _LanguageOption(code: 'nl', displayName: 'Nederlands', nativeName: 'Nederlands'),
    _LanguageOption(code: 'pt', displayName: 'Português', nativeName: 'Português'),
    _LanguageOption(code: 'da', displayName: 'Dansk', nativeName: 'Dansk'),
    _LanguageOption(code: 'fi', displayName: 'Suomi', nativeName: 'Suomi'),
    _LanguageOption(code: 'no', displayName: 'Norsk', nativeName: 'Norsk'),
    _LanguageOption(code: 'sv', displayName: 'Svenska', nativeName: 'Svenska'),
    _LanguageOption(code: 'cs', displayName: 'Čeština', nativeName: 'Čeština'),
    _LanguageOption(code: 'pl', displayName: 'Polski', nativeName: 'Polski'),
    _LanguageOption(code: 'sl', displayName: 'Slovenščina', nativeName: 'Slovenščina'),
    _LanguageOption(code: 'ro', displayName: 'Română', nativeName: 'Română'),
    _LanguageOption(code: 'ru', displayName: 'Русский', nativeName: 'Русский'),
    _LanguageOption(code: 'uk', displayName: 'Українська', nativeName: 'Українська'),
    _LanguageOption(code: 'el', displayName: 'Ελληνικά', nativeName: 'Ελληνικά'),
    _LanguageOption(code: 'tr', displayName: 'Türkçe', nativeName: 'Türkçe'),
    _LanguageOption(code: 'ja', displayName: '日本語', nativeName: '日本語'),
    _LanguageOption(code: 'ko', displayName: '한국어', nativeName: '한국어'),
    _LanguageOption(code: 'zh', displayName: '中文', nativeName: '中文'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.initialLanguageCode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize language code here when context is available
    _selectedLanguageCode ??= _translationService.getCurrentLanguage(context);
  }

  @override
  void didUpdateWidget(LanguageDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLanguageCode != oldWidget.initialLanguageCode) {
      setState(() {
        _selectedLanguageCode = widget.initialLanguageCode ?? _translationService.getCurrentLanguage(context);
      });
    }
  }

  void _onLanguageSelected(String? languageCode) {
    if (languageCode != null && languageCode != _selectedLanguageCode) {
      setState(() {
        _selectedLanguageCode = languageCode;
      });
      widget.onLanguageChanged?.call(languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Select your preferred language',
      hint: 'Choose language for the application interface',
      child: DropdownButtonFormField<String>(
        value: _selectedLanguageCode,
        decoration: InputDecoration(
          labelText: 'Language',
          labelStyle: AppTheme.bodyMedium,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sizeMedium,
            vertical: AppTheme.sizeSmall,
          ),
        ),
        hint: widget.showPlaceholder
            ? Text(
                'Select language...',
                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
              )
            : null,
        items: _languageOptions.map((language) {
          return DropdownMenuItem<String>(
            value: language.code,
            child: Row(
              children: [
                Text(
                  language.nativeName,
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                Text(
                  '(${language.displayName})',
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: _onLanguageSelected,
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down),
        elevation: 4,
        menuMaxHeight: 300,
      ),
    );
  }
}

class _LanguageOption {
  final String code;
  final String displayName;
  final String nativeName;

  const _LanguageOption({
    required this.code,
    required this.displayName,
    required this.nativeName,
  });
}
