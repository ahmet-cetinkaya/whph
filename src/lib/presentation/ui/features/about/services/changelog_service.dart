import 'package:http/http.dart' as http;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';

/// Service for fetching localized changelog from GitHub
class ChangelogService implements IChangelogService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/ahmet-cetinkaya/whph/main/fastlane/metadata/android';

  /// Maps app locale codes to fastlane directory names
  static const Map<String, String> _localeMapping = {
    'cs': 'cs-CZ',
    'da': 'da-DK',
    'de': 'de-DE',
    'el': 'el-GR',
    'en': 'en-US',
    'es': 'es-ES',
    'fi': 'fi-FI',
    'fr': 'fr-FR',
    'it': 'it-IT',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'nl': 'nl-NL',
    'no': 'nb-NO',
    'pl': 'pl-PL',
    'ro': 'ro-RO',
    'ru': 'ru-RU',
    'sl': 'sl-SI',
    'sv': 'sv-SE',
    'tr': 'tr-TR',
    'uk': 'uk-UA',
    'zh': 'zh-CN',
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
        Logger.warning('Failed to fetch changelog from $url: HTTP ${response.statusCode}');
        return null;
      }

      Logger.debug('Loaded changelog from $url');
      return response.body.trim();
    } catch (e) {
      Logger.warning('Failed to fetch changelog from $url: $e');
      return null;
    }
  }
}
