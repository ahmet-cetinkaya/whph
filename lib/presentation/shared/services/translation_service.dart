import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_multi/easy_localization_multi.dart';
import 'package:easy_localization_yaml/easy_localization_yaml.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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
    String translation = key.tr(namedArgs: namedArgs);

    if (translation == key && kDebugMode) debugPrint('❗Translation not found for key: $key');

    return translation;
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
      path: 'null',
      fallbackLocale: const Locale('en'),
      assetLoader: MultiAssetLoader([
        YamlAssetLoader(directory: 'lib/presentation/shared/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/about/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/app_usages/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/calendar/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/habits/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/notes/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/settings/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/tags/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/sync/assets/locales'),
        YamlAssetLoader(directory: 'lib/presentation/features/tasks/assets/locales'),
      ]),
      child: child,
    );
  }
}
