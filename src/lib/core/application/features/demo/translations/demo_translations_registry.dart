/// Demo data translations registry.
///
/// Maps locale codes to their demo translations.
library;

import 'demo_translations_en.dart';
import 'demo_translations_cs.dart';
import 'demo_translations_da.dart';
import 'demo_translations_de.dart';
import 'demo_translations_el.dart';
import 'demo_translations_es.dart';
import 'demo_translations_fi.dart';
import 'demo_translations_fr.dart';
import 'demo_translations_it.dart';
import 'demo_translations_ja.dart';
import 'demo_translations_ko.dart';
import 'demo_translations_nl.dart';
import 'demo_translations_no.dart';
import 'demo_translations_pl.dart';
import 'demo_translations_pt.dart';
import 'demo_translations_ro.dart';
import 'demo_translations_ru.dart';
import 'demo_translations_sl.dart';
import 'demo_translations_sv.dart';
import 'demo_translations_tr.dart';
import 'demo_translations_uk.dart';
import 'demo_translations_zh.dart';

/// Registry of all demo translations by locale.
class DemoTranslationsRegistry {
  /// Get translations for a specific locale.
  /// Falls back to English if locale not found.
  static Map<String, String> getTranslations(String locale) {
    return _translations[locale] ?? enDemoTranslations;
  }

  /// Get a translated string for a specific key and locale.
  static String translate(String key, String locale) {
    final translations = getTranslations(locale);
    return translations[key] ?? enDemoTranslations[key] ?? key;
  }

  /// All available translations by locale code.
  static final Map<String, Map<String, String>> _translations = {
    'cs': csDemoTranslations,
    'da': daDemoTranslations,
    'de': deDemoTranslations,
    'el': elDemoTranslations,
    'en': enDemoTranslations,
    'es': esDemoTranslations,
    'fi': fiDemoTranslations,
    'fr': frDemoTranslations,
    'it': itDemoTranslations,
    'ja': jaDemoTranslations,
    'ko': koDemoTranslations,
    'nl': nlDemoTranslations,
    'no': noDemoTranslations,
    'pl': plDemoTranslations,
    'pt': ptDemoTranslations,
    'ro': roDemoTranslations,
    'ru': ruDemoTranslations,
    'sl': slDemoTranslations,
    'sv': svDemoTranslations,
    'tr': trDemoTranslations,
    'uk': ukDemoTranslations,
    'zh': zhDemoTranslations,
  };
}
