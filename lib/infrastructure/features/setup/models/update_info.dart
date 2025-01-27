import 'dart:io';

class UpdateInfo {
  final String version;
  final String releaseUrl;
  final bool hasUpdate;
  final String? platformSpecificDownloadUrl;

  UpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.hasUpdate,
    this.platformSpecificDownloadUrl,
  });

  factory UpdateInfo.fromGitHubRelease(Map<String, dynamic> data, String currentVersion) {
    final version = (data['tag_name'] as String).substring(1);
    final releaseUrl = data['html_url'] as String;
    final hasUpdate = version != currentVersion;

    String? platformSpecificUrl;
    if (data['assets'] != null) {
      final assets = data['assets'] as List;
      final platformSuffix = _getPlatformSuffix();
      final asset = assets.cast<Map<String, dynamic>>().firstWhere(
            (asset) => asset['name'].toString().contains(platformSuffix),
            orElse: () => {},
          );
      platformSpecificUrl = asset['browser_download_url'] as String?;
    }

    return UpdateInfo(
      version: version,
      releaseUrl: releaseUrl,
      hasUpdate: hasUpdate,
      platformSpecificDownloadUrl: platformSpecificUrl,
    );
  }

  static String _getPlatformSuffix() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    return '';
  }
}
