import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Service for handling background translation when EasyLocalization is not available
class BackgroundTranslationService {
  static final BackgroundTranslationService _instance = BackgroundTranslationService._internal();
  factory BackgroundTranslationService() => _instance;
  BackgroundTranslationService._internal();

  Map<String, Map<String, String>>? _translationCache;
  String? _currentLocale;

  /// Initialize the service with current locale and cache translations
  Future<void> initialize() async {
    await _loadCurrentLocale();
    await _loadTranslations();
  }

  /// Load the current locale from settings
  Future<void> _loadCurrentLocale() async {
    try {
      final mediator = container.resolve<Mediator>();
      final response = await mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.currentLocale),
      );
      _currentLocale = response.value.isNotEmpty ? response.value : 'en'; // Default to English
    } catch (e) {
      _currentLocale = 'en'; // Fallback to English
      Logger.error('BackgroundTranslationService: Failed to load locale, using default: $e');
    }
  }

  /// Save the current locale to settings
  Future<void> saveCurrentLocale(String locale) async {
    try {
      final mediator = container.resolve<Mediator>();
      await mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(
        SaveSettingCommand(
          key: SettingKeys.currentLocale,
          value: locale,
          valueType: SettingValueType.string,
        ),
      );
      _currentLocale = locale;

      // Reload translations for new locale
      await _loadTranslations();
    } catch (e) {
      Logger.error('BackgroundTranslationService: Failed to save locale: $e');
    }
  }

  /// Load translations from asset files for current locale
  Future<void> _loadTranslations() async {
    if (_currentLocale == null) return;

    try {
      _translationCache = {_currentLocale!: {}};

      // List of all locale directories in the project
      final localeDirectories = [
        'lib/presentation/ui/features/about/assets/locales',
        'lib/presentation/ui/features/app_usages/assets/locales',
        'lib/presentation/ui/features/calendar/assets/locales',
        'lib/presentation/ui/features/habits/assets/locales',
        'lib/presentation/ui/features/notes/assets/locales',
        'lib/presentation/ui/features/settings/assets/locales',
        'lib/presentation/ui/features/sync/assets/locales',
        'lib/presentation/ui/features/tags/assets/locales',
        'lib/presentation/ui/features/tasks/assets/locales',
        'lib/presentation/ui/shared/assets/locales',
      ];

      // Load all translation files for current locale
      for (final directory in localeDirectories) {
        await _loadTranslationFile(directory, _currentLocale!);
      }

      // Also try to load English as fallback
      if (_currentLocale != 'en') {
        _translationCache!['en'] = {};
        for (final directory in localeDirectories) {
          await _loadTranslationFile(directory, 'en');
        }
      }

      Logger.debug('BackgroundTranslationService: Loaded translations for locale: $_currentLocale');
    } catch (e) {
      Logger.error('BackgroundTranslationService: Failed to load translations: $e');
    }
  }

  /// Load a specific translation file
  Future<void> _loadTranslationFile(String path, String locale) async {
    try {
      final yamlContent = await rootBundle.loadString('$path/$locale.yaml');
      final Map<String, dynamic> yamlMap = _parseSimpleYaml(yamlContent);

      // Flatten the nested structure to dot notation
      final flatMap = _flattenMap(yamlMap);

      if (_translationCache![locale] == null) {
        _translationCache![locale] = {};
      }

      _translationCache![locale]!.addAll(flatMap);
    } catch (e) {
      // File might not exist for this locale, continue silently
      if (kDebugMode) {
        Logger.debug('BackgroundTranslationService: Could not load $path/$locale.yaml: $e');
      }
    }
  }

  /// Parse simple YAML content (improved implementation for nested structures)
  Map<String, dynamic> _parseSimpleYaml(String yamlContent) {
    final Map<String, dynamic> result = {};
    final lines = yamlContent.split('\n');
    final List<MapEntry<int, String>> indentStack = []; // Track indent level and key

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;

      // Get indentation level (count leading spaces)
      final indentLevel = line.length - line.trimLeft().length;
      final trimmed = line.trim();

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) {
        // Skip malformed lines without colons
        continue;
      }

      final key = trimmed.substring(0, colonIndex).trim();
      final value = trimmed.substring(colonIndex + 1).trim();

      // Clean the indent stack - remove entries with higher or equal indent levels
      indentStack.removeWhere((entry) => entry.key >= indentLevel);

      // Add current key to stack
      indentStack.add(MapEntry(indentLevel, key));

      // Build the full path
      final pathParts = indentStack.map((entry) => entry.value).toList();
      final currentPath = pathParts.join('.');

      // Handle multiline strings (|)
      if (value == '|' || value == '>') {
        final multilineBuffer = StringBuffer();

        // Collect all following lines that are part of this multiline string
        int j = i + 1;
        while (j < lines.length) {
          final nextLine = lines[j];
          final nextTrimmed = nextLine.trim();

          // Stop if we hit an empty line or a line with same/less indentation (new key)
          if (nextTrimmed.isEmpty) {
            j++;
            continue;
          }

          final nextIndent = nextLine.length - nextLine.trimLeft().length;
          if (nextIndent <= indentLevel) {
            break; // New key at same or higher level
          }

          // Add line to multiline content
          if (multilineBuffer.isNotEmpty) {
            multilineBuffer.write('\n');
          }
          multilineBuffer.write(nextTrimmed);
          j++;
        }

        i = j - 1; // Update loop counter to skip processed lines
      }
      // Store value if it's not empty
      else if (value.isNotEmpty) {
        final cleanValue = value.replaceAll('"', '').replaceAll("'", '');
        result[currentPath] = cleanValue;
      }
    }

    return result;
  }

  /// Flatten nested map to dot notation
  Map<String, String> _flattenMap(Map<String, dynamic> map, [String prefix = '']) {
    final Map<String, String> result = {};

    map.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        result.addAll(_flattenMap(value, newKey));
      } else if (value is String) {
        result[newKey] = value;
      }
    });

    return result;
  }

  /// Translate a key using cached translations with named arguments support
  String translate(String key, {Map<String, String>? namedArgs}) {
    if (_translationCache == null || _currentLocale == null) {
      return key;
    }

    String? translation = _translationCache![_currentLocale]?[key];

    if (translation == null) {
      // Try fallback to English if current locale fails
      if (_currentLocale != 'en') {
        translation = _translationCache!['en']?[key];
      }

      if (translation == null) {
        Logger.warning('BackgroundTranslationService: Translation not found for key: $key');
        return key;
      }
    }

    // Handle named arguments
    if (namedArgs != null && namedArgs.isNotEmpty) {
      namedArgs.forEach((argKey, argValue) {
        translation = translation!.replaceAll('{$argKey}', argValue);
      });
    }

    return translation!;
  }

  /// Translate with fallback - if key is not found, return the fallback text
  String translateWithFallback(String key, String fallback, {Map<String, String>? namedArgs}) {
    if (_translationCache == null || _currentLocale == null) {
      return fallback;
    }

    String? translation = _translationCache![_currentLocale]?[key];

    if (translation == null) {
      // Try fallback to English if current locale fails
      if (_currentLocale != 'en') {
        translation = _translationCache!['en']?[key];
      }

      if (translation == null) {
        return fallback;
      }
    }

    // Handle named arguments
    if (namedArgs != null && namedArgs.isNotEmpty) {
      namedArgs.forEach((argKey, argValue) {
        translation = translation!.replaceAll('{$argKey}', argValue);
      });
    }

    return translation!;
  }

  /// Get the current locale
  String get currentLocale => _currentLocale ?? 'en';

  // Test helper methods - only available in test mode
  @visibleForTesting
  Map<String, dynamic> parseSimpleYamlForTest(String yamlContent) {
    return _parseSimpleYaml(yamlContent);
  }

  @visibleForTesting
  void setTranslationCacheForTest(Map<String, Map<String, String>> cache) {
    _translationCache = cache;
  }

  @visibleForTesting
  void setCurrentLocaleForTest(String locale) {
    _currentLocale = locale;
  }

  @visibleForTesting
  Future<void> loadCurrentLocaleForTest() async {
    await _loadCurrentLocale();
  }

  @visibleForTesting
  void clearCacheForTest() {
    _translationCache = null;
    _currentLocale = null;
  }
}
