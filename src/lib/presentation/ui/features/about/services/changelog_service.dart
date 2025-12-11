import 'package:http/http.dart' as http;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';

/// Service for fetching localized changelog from GitHub
class ChangelogService implements IChangelogService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/ahmet-cetinkaya/whph/main/fastlane/metadata/android';

  /// Maps app locale codes to fastlane directory names
  /// Based on supported locales in translation_service.dart
  /// Directory names follow Google Play Console format
  static const Map<String, String> _localeMapping = {
    'cs': 'cs', // Czech
    'da': 'da', // Danish
    'de': 'de', // German
    'el': 'el', // Greek
    'en': 'en-US', // English
    'es': 'es-ES', // Spanish
    'fi': 'fi', // Finnish
    'fr': 'fr-FR', // French
    'it': 'it', // Italian
    'ja': 'ja', // Japanese
    'ko': 'ko', // Korean
    'nl': 'nl', // Dutch
    'no': 'no', // Norwegian
    'pl': 'pl', // Polish
    'pt': 'pt-PT', // Portuguese
    'ro': 'ro', // Romanian
    'ru': 'ru', // Russian
    'sl': 'sl', // Slovenian
    'sv': 'sv', // Swedish
    'tr': 'tr', // Turkish
    'uk': 'uk', // Ukrainian
    'zh': 'zh-CN', // Chinese
  };

  static const String _fallbackLocale = 'en-US';

  @override
  Future<ChangelogEntry?> fetchChangelog(String localeCode) async {
    final buildNumber = AppInfo.buildNumber;
    final fastlaneLocale = _localeMapping[localeCode] ?? _fallbackLocale;

    // Try locale-specific changelog first
    var content = await _fetchChangelogFromGitHub(fastlaneLocale, buildNumber);

    // Fallback to English if not found
    if (content == null && fastlaneLocale != _fallbackLocale) {
      Logger.debug('Changelog not found for $fastlaneLocale, falling back to $_fallbackLocale');
      content = await _fetchChangelogFromGitHub(_fallbackLocale, buildNumber);
    }

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
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'WHPH/${AppInfo.version}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        Logger.debug('Failed to fetch changelog from $url: HTTP ${response.statusCode}');
        return null;
      }

      Logger.debug('Loaded changelog from $url');
      return response.body.trim();
    } catch (e) {
      Logger.debug('Failed to fetch changelog from $url: $e');
      return null;
    }
  }
}
