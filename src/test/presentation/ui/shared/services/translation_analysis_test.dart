// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Test TranslationKey classes throughout the project to detect missing translations
void main() {
  group('Translation Keys Analysis', () {
    test('should detect missing translations', () async {
      final analyzer = TranslationKeysAnalyzer();
      final result = await analyzer.analyze();

      final totalMissingTranslations =
          result.missingTranslations.values.fold<int>(0, (sum, missing) => sum + missing.length);

      if (totalMissingTranslations > 0) {
        print('Missing translations: $totalMissingTranslations');
        for (final entry in result.missingTranslations.entries) {
          final featureName = TranslationKeysAnalyzer()._extractFeatureNameFromPath(entry.key);

          final groupedByKey = <String, List<String>>{};
          for (final missing in entry.value) {
            groupedByKey.putIfAbsent(missing.key, () => []).add(missing.language);
          }

          print('  $featureName:');
          for (final keyEntry in groupedByKey.entries) {
            print('    ${keyEntry.key}: ${keyEntry.value.join(', ')}');
          }
        }
      } else {
        print('✅ All translations complete');
      }

      // Assert that there are no missing translations
      expect(totalMissingTranslations, equals(0),
          reason: 'All translation keys must have corresponding translations in all supported languages');
    }, timeout: Timeout(Duration(minutes: 5)));

    test('should detect untranslated strings (remaining in English)', () async {
      final analyzer = TranslationKeysAnalyzer();
      final result = await analyzer.analyzeUntranslatedStrings();

      final totalUntranslatedStrings =
          result.untranslatedStrings.values.fold<int>(0, (sum, untranslated) => sum + untranslated.length);

      if (totalUntranslatedStrings > 0) {
        print('Untranslated strings: $totalUntranslatedStrings');
        for (final entry in result.untranslatedStrings.entries) {
          final featureName = analyzer._extractFeatureNameFromPath(entry.key);

          final groupedByKey = <String, List<String>>{};
          for (final untranslated in entry.value) {
            groupedByKey.putIfAbsent(untranslated.key, () => []).add(untranslated.language);
          }

          print('  $featureName:');
          for (final keyEntry in groupedByKey.entries) {
            print('    ${keyEntry.key}: ${keyEntry.value.join(', ')}');
          }
        }
      } else {
        print('✅ All translations localized');
      }

      // Assert that there are no untranslated strings
      expect(totalUntranslatedStrings, equals(0),
          reason: 'All translation values should be properly translated, not remaining in English');
    }, timeout: Timeout(Duration(minutes: 5)));
  });
}

class TranslationKeysAnalyzer {
  // Supported languages
  static const supportedLanguages = [
    'cs', // Czech
    'da', // Danish
    'de', // German
    'el', // Greek
    'en', // English
    'es', // Spanish
    'fi', // Finnish
    'fr', // French
    'it', // Italian
    'ja', // Japanese
    'ko', // Korean
    'nl', // Dutch
    'no', // Norwegian
    'pl', // Polish
    'pt', // Portuguese
    'ro', // Romanian
    'ru', // Russian
    'sl', // Slovenian
    'sv', // Swedish
    'tr', // Turkish
    'uk', // Ukrainian
    'zh', // Chinese
  ];

  // TranslationKey file paths
  static const translationKeyPaths = [
    'lib/presentation/ui/features/about/constants/about_translation_keys.dart',
    'lib/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart',
    'lib/presentation/ui/features/calendar/constants/calendar_translation_keys.dart',
    'lib/presentation/ui/features/habits/constants/habit_translation_keys.dart',
    'lib/presentation/ui/features/notes/constants/note_translation_keys.dart',
    'lib/presentation/ui/features/settings/constants/settings_translation_keys.dart',
    'lib/presentation/ui/features/sync/constants/sync_translation_keys.dart',
    'lib/presentation/ui/features/tags/constants/tag_translation_keys.dart',
    'lib/presentation/ui/features/tasks/constants/task_translation_keys.dart',
    'lib/presentation/ui/shared/constants/shared_translation_keys.dart',
    'lib/core/application/features/about/constants/about_translation_keys.dart',
    'lib/core/application/features/app_usages/constants/app_usage_translation_keys.dart',
    'lib/core/application/features/calendar/constants/calendar_translation_keys.dart',
    'lib/core/application/features/habits/constants/habit_translation_keys.dart',
    'lib/core/application/features/notes/constants/note_translation_keys.dart',
    'lib/core/application/features/settings/constants/setting_translation_keys.dart',
    'lib/core/application/features/sync/constants/sync_translation_keys.dart',
    'lib/core/application/features/tags/constants/tag_translation_keys.dart',
    'lib/core/application/features/tasks/constants/task_translation_keys.dart',
    'lib/core/application/shared/constants/shared_translation_keys.dart',
  ];

  Future<AnalysisResult> analyze() async {
    final missingTranslations = <String, List<MissingTranslation>>{};

    // Analyze each TranslationKey file
    for (final path in translationKeyPaths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      // Extract keys from TranslationKey file
      final keys = await _extractKeysFromFile(file);
      if (keys.isEmpty) continue;

      // Find missing translations
      final missing = await _findMissingTranslations(keys, path);
      if (missing.isNotEmpty) {
        missingTranslations[path] = missing;
      }
    }

    return AnalysisResult(
      missingTranslations: missingTranslations,
    );
  }

  Future<UntranslatedAnalysisResult> analyzeUntranslatedStrings() async {
    final untranslatedStrings = <String, List<UntranslatedString>>{};

    // Analyze each TranslationKey file
    for (final path in translationKeyPaths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      // Extract keys from TranslationKey file
      final keys = await _extractKeysFromFile(file);
      if (keys.isEmpty) continue;

      // Find untranslated strings
      final untranslated = await _findUntranslatedStrings(keys, path);
      if (untranslated.isNotEmpty) {
        untranslatedStrings[path] = untranslated;
      }
    }

    return UntranslatedAnalysisResult(
      untranslatedStrings: untranslatedStrings,
    );
  }

  /// Extracts translation keys from TranslationKey file
  Future<Map<String, String>> _extractKeysFromFile(File file) async {
    final content = await file.readAsString();
    final keys = <String, String>{};

    // Find constants defined with static const String
    final pattern = RegExp("static\\s+const\\s+String\\s+(\\w+)\\s*=\\s*['\"]([^'\"]+)['\"]");
    final matches = pattern.allMatches(content);

    for (final match in matches) {
      final fieldName = match.group(1)!;
      final translationKey = match.group(2)!;
      keys[fieldName] = translationKey;
    }

    return keys;
  }

  /// Finds missing translations
  Future<List<MissingTranslation>> _findMissingTranslations(Map<String, String> keys, String translationKeyPath) async {
    final missingTranslations = <MissingTranslation>[];

    // Extract feature name from path
    final featureName = _extractFeatureNameFromPath(translationKeyPath);

    for (final language in supportedLanguages) {
      // Find related YAML file
      final yamlPath = _getYamlPathForFeature(featureName, language);
      final yamlFile = File(yamlPath);

      if (!yamlFile.existsSync()) {
        // If YAML file doesn't exist, all keys are missing
        for (final translationKey in keys.values) {
          missingTranslations.add(MissingTranslation(
            key: translationKey,
            language: language,
          ));
        }
        continue;
      }

      // Parse YAML file
      final yamlContent = await yamlFile.readAsString();
      final yamlData = loadYaml(yamlContent) as Map?;
      if (yamlData == null) continue;

      // Check translation for each key
      for (final translationKey in keys.values) {
        if (!_hasTranslation(yamlData, translationKey)) {
          missingTranslations.add(MissingTranslation(
            key: translationKey,
            language: language,
          ));
        }
      }
    }

    return missingTranslations;
  }

  /// Finds untranslated strings (remaining in English)
  Future<List<UntranslatedString>> _findUntranslatedStrings(Map<String, String> keys, String translationKeyPath) async {
    final untranslatedStrings = <UntranslatedString>[];

    // Extract feature name from path
    final featureName = _extractFeatureNameFromPath(translationKeyPath);

    // Get English translations as reference
    final englishYamlPath = _getYamlPathForFeature(featureName, 'en');
    final englishYamlFile = File(englishYamlPath);

    if (!englishYamlFile.existsSync()) return untranslatedStrings;

    final englishYamlContent = await englishYamlFile.readAsString();
    final englishYamlData = loadYaml(englishYamlContent) as Map?;
    if (englishYamlData == null) return untranslatedStrings;

    // Check other languages for untranslated strings
    for (final language in supportedLanguages) {
      if (language == 'en') continue; // Skip English itself

      // Find related YAML file
      final yamlPath = _getYamlPathForFeature(featureName, language);
      final yamlFile = File(yamlPath);

      if (!yamlFile.existsSync()) continue;

      // Parse YAML file
      final yamlContent = await yamlFile.readAsString();
      final yamlData = loadYaml(yamlContent) as Map?;
      if (yamlData == null) continue;

      // Check each translation key
      for (final translationKey in keys.values) {
        final englishValue = _getTranslationValue(englishYamlData, translationKey);
        final localizedValue = _getTranslationValue(yamlData, translationKey);

        // If the localized value is the same as English value, it's likely untranslated
        if (englishValue != null &&
            localizedValue != null &&
            englishValue == localizedValue &&
            englishValue.trim().isNotEmpty &&
            englishValue.length > 20 &&
            !englishValue.contains('{')) {
          untranslatedStrings.add(UntranslatedString(
            key: translationKey,
            value: localizedValue,
            language: language,
          ));
        }
      }
    }

    return untranslatedStrings;
  }

  /// Extracts feature name from TranslationKey file path
  String _extractFeatureNameFromPath(String path) {
    if (path.contains('/shared/')) return 'shared';
    if (path.contains('/features/')) {
      final regex = RegExp("/features/(\\w+)/");
      final match = regex.firstMatch(path);
      return match?.group(1) ?? 'unknown';
    }
    return 'unknown';
  }

  /// Creates YAML file path for feature and language
  String _getYamlPathForFeature(String featureName, String language) {
    if (featureName == 'shared') {
      return 'lib/presentation/ui/shared/assets/locales/$language.yaml';
    }
    return 'lib/presentation/ui/features/$featureName/assets/locales/$language.yaml';
  }

  /// Checks if a specific translation key exists in YAML data
  bool _hasTranslation(Map yamlData, String translationKey) {
    final keyParts = translationKey.split('.');
    dynamic current = yamlData;

    for (final part in keyParts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return false;
      }
    }

    return current != null;
  }

  /// Gets the translation value for a specific key from YAML data
  String? _getTranslationValue(Map yamlData, String translationKey) {
    final keyParts = translationKey.split('.');
    dynamic current = yamlData;

    for (final part in keyParts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current?.toString();
  }
}

class AnalysisResult {
  final Map<String, List<MissingTranslation>> missingTranslations;

  const AnalysisResult({
    required this.missingTranslations,
  });
}

class MissingTranslation {
  final String key;
  final String language;

  const MissingTranslation({
    required this.key,
    required this.language,
  });
}

class UntranslatedAnalysisResult {
  final Map<String, List<UntranslatedString>> untranslatedStrings;

  const UntranslatedAnalysisResult({
    required this.untranslatedStrings,
  });
}

class UntranslatedString {
  final String key;
  final String value;
  final String language;

  const UntranslatedString({
    required this.key,
    required this.value,
    required this.language,
  });
}
