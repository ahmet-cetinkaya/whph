import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

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
      Logger.debug('BackgroundTranslationService: Failed to load locale, using default: $e');
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
        'lib/src/presentation/ui/features/about/assets/locales',
        'lib/src/presentation/ui/features/app_usages/assets/locales',
        'lib/src/presentation/ui/features/calendar/assets/locales',
        'lib/src/presentation/ui/features/habits/assets/locales',
        'lib/src/presentation/ui/features/notes/assets/locales',
        'lib/src/presentation/ui/features/settings/assets/locales',
        'lib/src/presentation/ui/features/sync/assets/locales',
        'lib/src/presentation/ui/features/tags/assets/locales',
        'lib/src/presentation/ui/features/tasks/assets/locales',
        'lib/src/presentation/ui/shared/assets/locales',
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
      Logger.debug('BackgroundTranslationService: Loaded ${flatMap.length} translations from $path/$locale.yaml');

      // Log notification-specific keys for debugging
      final notificationKeys = flatMap.keys.where((key) => key.contains('notification')).toList();
      if (notificationKeys.isNotEmpty) {
        Logger.debug('BackgroundTranslationService: Found notification keys: $notificationKeys');
      }
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
    final List<String> indentStack = [];
    String currentPath = '';

    for (final line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;

      // Get indentation level
      final indentLevel = line.length - line.trimLeft().length;
      final trimmed = line.trim();

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) {
        // Skip malformed lines without colons, but log for debugging
        if (kDebugMode) {
          Logger.debug('BackgroundTranslationService: Skipping malformed line: $trimmed');
        }
        continue;
      }

      final key = trimmed.substring(0, colonIndex).trim();
      final value = trimmed.substring(colonIndex + 1).trim();

      // Update path based on indentation
      if (indentLevel == 0) {
        indentStack.clear();
        indentStack.add(key);
        currentPath = key;
      } else {
        // Find correct level in stack
        final targetLevel = indentLevel ~/ 2; // Assuming 2-space indentation

        if (targetLevel < indentStack.length) {
          // Go back to appropriate level
          indentStack.removeRange(targetLevel, indentStack.length);
        }

        // Add current key
        indentStack.add(key);
        currentPath = indentStack.join('.');
      }

      // Store value if it's not empty and doesn't look like multiline content
      if (value.isNotEmpty && !value.startsWith('|') && !value.startsWith('>')) {
        result[currentPath] = value.replaceAll('"', '').replaceAll("'", '');
      } else if (value.isEmpty) {
        // For keys without values (like section headers), still add them to result
        // This ensures that 'tasks:' gets added even if it has no immediate value
        result[currentPath] = '';
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
      Logger.debug('BackgroundTranslationService: Translation cache not initialized, returning key: $key');
      return key;
    }

    String? translation = _translationCache![_currentLocale]?[key];

    if (translation == null) {
      // Try fallback to English if current locale fails
      if (_currentLocale != 'en') {
        translation = _translationCache!['en']?[key];
      }

      if (translation == null) {
        Logger.debug('BackgroundTranslationService: Translation not found for key: $key');
        Logger.debug(
            'BackgroundTranslationService: Available keys for locale $_currentLocale: ${_translationCache![_currentLocale]?.keys.take(10)}');
        return key;
      }
    }

    // Handle named arguments
    if (namedArgs != null) {
      namedArgs.forEach((argKey, argValue) {
        translation = translation!.replaceAll('{$argKey}', argValue);
      });
    }

    Logger.debug('BackgroundTranslationService: Successfully translated key: $key -> $translation');
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
