/// Data model for a changelog entry
class ChangelogEntry {
  final String version;
  final String content;

  ChangelogEntry({
    required this.version,
    required this.content,
  });
}

/// Interface for changelog service
abstract class IChangelogService {
  /// Fetches changelog for the current build number and specified locale
  /// Falls back to English if locale-specific changelog not found
  Future<ChangelogEntry?> fetchChangelog(String localeCode);
}
