import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_multi/easy_localization_multi.dart';
import 'package:easy_localization_yaml/easy_localization_yaml.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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

    if (translation == key && kDebugMode) {
      Logger.error('[Error] [TranslationService] Translation not found for key: $key');
    }

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
        YamlAssetLoader(directory: 'lib/src/presentation/ui/shared/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/about/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/app_usages/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/calendar/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/habits/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/notes/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/settings/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/tags/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/sync/assets/locales'),
        YamlAssetLoader(directory: 'lib/src/presentation/ui/features/tasks/assets/locales'),
      ]),
      child: child,
    );
  }
}
