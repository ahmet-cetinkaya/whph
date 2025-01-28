import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import '../services/abstraction/i_translation_service.dart';

class TranslationService implements ITranslationService {
  static const _supportedLocales = [
    Locale('en'),
    Locale('tr'),
  ];

  @override
  Future<void> init() async {
    await EasyLocalization.ensureInitialized();
  }

  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    return key.tr(namedArgs: namedArgs);
  }

  @override
  Future<void> changeLanguage(BuildContext context, String languageCode) async {
    await context.setLocale(Locale(languageCode));
    if (context.mounted) Navigator.of(context).pushReplacementNamed(SettingsPage.route);
  }

  @override
  String getCurrentLanguage(BuildContext context) => context.locale.languageCode;

  @override
  Widget wrapWithTranslations(Widget child) {
    return EasyLocalization(
      supportedLocales: _supportedLocales,
      path: 'lib/presentation/shared/assets/locales',
      fallbackLocale: const Locale('en'),
      assetLoader: YamlAssetLoader(),
      child: child,
    );
  }
}
