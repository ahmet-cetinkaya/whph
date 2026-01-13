import 'package:http/http.dart' as http;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:flutter/foundation.dart';

/// Service for fetching localized changelog from GitHub
class ChangelogService implements IChangelogService {
  final http.Client _client;

  ChangelogService({http.Client? client}) : _client = client ?? http.Client();
  static const String _baseUrl =
      'https://raw.githubusercontent.com/ahmet-cetinkaya/whph/main/fastlane/metadata/android';

  /// Maps app locale codes to fastlane directory names
  /// Based on supported locales in translation_service.dart
  /// Directory names follow Google Play Console format
  static const Map<String, String> _localeMapping = {
    'cs': 'cs-CZ', // Czech
    'da': 'da-DK', // Danish
    'de': 'de-DE', // German
    'el': 'el-GR', // Greek
    'en': 'en-US', // English
    'es': 'es-ES', // Spanish
    'fi': 'fi-FI', // Finnish
    'fr': 'fr-FR', // French
    'it': 'it-IT', // Italian
    'ja': 'ja-JP', // Japanese
    'ko': 'ko-KR', // Korean
    'nl': 'nl-NL', // Dutch
    'no': 'no-NO', // Norwegian
    'pl': 'pl-PL', // Polish
    'pt': 'pt-PT', // Portuguese
    'ro': 'ro', // Romanian
    'ru': 'ru-RU', // Russian
    'sl': 'sl', // Slovenian
    'sv': 'sv-SE', // Swedish
    'tr': 'tr-TR', // Turkish
    'uk': 'uk', // Ukrainian
    'zh': 'zh-CN', // Chinese
  };

  static const String _fallbackLocale = 'en-US';

  /// Simple in-memory cache to prevent repeated network calls
  static final Map<String, String?> _cache = {};

  /// Get locale mapping for testing purposes
  static Map<String, String> get localeMapping => Map.unmodifiable(_localeMapping);

  @visibleForTesting
  static void clearCache() => _cache.clear();

  @override
  Future<ChangelogEntry?> fetchChangelog(String localeCode) async {
    final buildNumber = AppInfo.buildNumber;
    final fastlaneLocale = _localeMapping[localeCode] ?? _fallbackLocale;

    // Create cache key
    final cacheKey = '${fastlaneLocale}_$buildNumber';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      Logger.debug('Using cached changelog for $fastlaneLocale v$buildNumber');
      final cachedContent = _cache[cacheKey];
      if (cachedContent != null) {
        return ChangelogEntry(
          version: AppInfo.version,
          content: cachedContent,
        );
      }
      // If cached content is null, it means we already tried and failed
      Logger.debug('Changelog not found (cached) for build $buildNumber');
      return null;
    }

    // Try locale-specific changelog first
    var content = await _fetchChangelogFromGitHub(fastlaneLocale, buildNumber);

    // Fallback to English if not found
    if (content == null && fastlaneLocale != _fallbackLocale) {
      Logger.debug('Changelog not found for $fastlaneLocale, falling back to $_fallbackLocale');
      content = await _fetchChangelogFromGitHub(_fallbackLocale, buildNumber);
    }

    // Cache the result (null if not found)
    _cache[cacheKey] = content;

    if (content == null) {
      Logger.debug('No changelog found for build $buildNumber');
      return null;
    }

    return ChangelogEntry(
      version: AppInfo.version,
      content: content,
    );
  }

  /// Fetches changelog content from GitHub
  Future<String?> _fetchChangelogFromGitHub(String locale, String buildNumber) async {
    final url = '$_baseUrl/$locale/changelogs/$buildNumber.txt';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'WHPH/${AppInfo.version}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        Logger.debug('Failed to fetch changelog from $url: HTTP ${response.statusCode}');
        return null;
      }

      Logger.debug('Loaded changelog from $url');
      // Replace • with - for markdown syntax, ensuring each list item is properly formatted
      // First replace '• ' (bullet with space) then handle edge case of bullet without space
      return response.body.trim().replaceAll('• ', '- ').replaceAll('•', '- ');
    } catch (e) {
      Logger.warning('Failed to fetch changelog from $url: $e');
      return null;
    }
  }
}
