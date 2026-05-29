class ChangelogEntry {
  final String version;
  final String content;

  const ChangelogEntry({
    required this.version,
    required this.content,
  });
}

abstract class IChangelogService {
  /// Fetches changelog for the current build number and specified locale, falling back to English if not found
  Future<ChangelogEntry?> fetchChangelog(String localeCode);
}
