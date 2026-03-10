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
    String version = data['tag_name'] as String;
    // Remove 'v' prefix if present
    if (version.startsWith('v')) {
      version = version.substring(1);
    }

    final releaseUrl = data['html_url'] as String;
    final hasUpdate = _isNewerVersion(version, currentVersion);

    String? platformSpecificUrl;
    if (data['assets'] != null) {
      final assets = data['assets'] as List;
      final platformSuffix = _getPlatformSuffix();

      // For Windows, prefer portable version over installer for updates
      String targetFileName;
      if (Platform.isWindows) {
        targetFileName = '$platformSuffix-portable.zip';
      } else {
        targetFileName = platformSuffix;
      }

      // First try to find the preferred file type
      Map<String, dynamic> asset = assets.cast<Map<String, dynamic>>().firstWhere(
            (asset) => asset['name'].toString().contains(targetFileName),
            orElse: () => <String, dynamic>{},
          );

      // If preferred not found and it's Windows, fallback to any Windows file
      if (asset.isEmpty && Platform.isWindows) {
        asset = assets.cast<Map<String, dynamic>>().firstWhere(
              (asset) => asset['name'].toString().contains(platformSuffix),
              orElse: () => <String, dynamic>{},
            );
      }

      platformSpecificUrl = asset['browser_download_url'] as String?;
    }

    return UpdateInfo(
      version: version,
      releaseUrl: releaseUrl,
      hasUpdate: hasUpdate,
      platformSpecificDownloadUrl: platformSpecificUrl,
    );
  }

  static bool _isNewerVersion(String latestVersion, String currentVersion) {
    try {
      final latestParts = latestVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Pad with zeros if needed to ensure same length
      while (latestParts.length < currentParts.length) {
        latestParts.add(0);
      }
      while (currentParts.length < latestParts.length) {
        currentParts.add(0);
      }

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      // Fallback to string comparison if semantic parsing fails
      return latestVersion != currentVersion;
    }
  }

  static String _getPlatformSuffix() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    return '';
  }
}
