import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/about/constants/about_translation_keys.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class AppAbout extends StatelessWidget {
  AppAbout({super.key});

  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Image(
                image: AssetImage(AppInfo.logoPath),
                width: 100,
                height: 100,
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${AppInfo.name} (${AppInfo.shortName})",
                      style: AppTheme.headlineMedium,
                    ),
                    Text(
                      _translationService.translate(
                        AboutTranslationKeys.version,
                        namedArgs: {'version': AppInfo.version},
                      ),
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sizeMedium),
        Text(
          _translationService.translate(
            AboutTranslationKeys.description,
            namedArgs: {'appName': AppInfo.name},
          ),
          style: AppTheme.bodyMedium,
        ),
        Center(
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildExternalLink(
                title: _translationService.translate(AboutTranslationKeys.websiteLink),
                icon: Icons.web,
                url: AppInfo.websiteUrl,
              ),
              _buildExternalLink(
                title: _translationService.translate(AboutTranslationKeys.sourceCodeLink),
                icon: Icons.code,
                url: AppInfo.sourceCodeUrl,
              ),
              FutureBuilder<String>(
                future: _prepareFeedbackIssueUrl(context),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator.adaptive());
                  }
                  return _buildExternalLink(
                    title: _translationService.translate(AboutTranslationKeys.feedback),
                    icon: Icons.feedback,
                    url: snapshot.data ?? '${AppInfo.sourceCodeUrl}/issues/new',
                  );
                },
              ),
              _buildExternalLink(
                title: _translationService.translate(AboutTranslationKeys.contact),
                icon: Icons.mail,
                url: 'mailto:${AppInfo.supportEmail}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExternalLink({required String title, required String url, required IconData icon}) {
    return TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      label: Text(
        title,
        style: AppTheme.bodyLarge,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      icon: Icon(icon),
    );
  }

  Future<String> _prepareFeedbackIssueUrl(BuildContext context) async {
    final deviceInfo = await _getDeviceInfo();

    // If the context is not mounted, return a default URL to avoid errors
    if (!context.mounted) return '${AppInfo.sourceCodeUrl}/issues/new';

    final queryParams = <String, String>{
      'template': 'general_feedback.yml',
      'title': '[FEEDBACK] ',
      'app-version': AppInfo.version,
      'device-model': deviceInfo['deviceModel'] ?? 'Unknown',
      'operating-system': '${deviceInfo['osName']} ${deviceInfo['osVersion']}',
      'app-language': _translationService.getCurrentLanguage(context),
      'screen-size': '${MediaQuery.of(context).size.width.toInt()}x${MediaQuery.of(context).size.height.toInt()}',
    };

    final uri = Uri.parse('${AppInfo.sourceCodeUrl}/issues/new').replace(
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'deviceModel': '${androidInfo.brand} ${androidInfo.model}',
          'osName': 'Android',
          'osVersion': androidInfo.version.release,
        };
      }
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'deviceModel': '${iosInfo.name} ${iosInfo.model}',
          'osName': 'iOS',
          'osVersion': iosInfo.systemVersion,
        };
      }
      if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return {
          'deviceModel': linuxInfo.prettyName,
          'osName': 'Linux',
          'osVersion': linuxInfo.versionId ?? 'Unknown',
        };
      }
      if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfo.macOsInfo;
        return {
          'deviceModel': macOsInfo.model,
          'osName': 'macOS',
          'osVersion': '${macOsInfo.majorVersion}.${macOsInfo.minorVersion}.${macOsInfo.patchVersion}',
        };
      }
      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return {
          'deviceModel': windowsInfo.productName,
          'osName': 'Windows',
          'osVersion': windowsInfo.displayVersion,
        };
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {
      'deviceModel': _getBasicDeviceModel(),
      'osName': _getOSName(),
      'osVersion': Platform.operatingSystemVersion,
    };
  }

  String _getBasicDeviceModel() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isLinux) return 'Linux Device';
    if (Platform.isMacOS) return 'macOS Device';
    if (Platform.isWindows) return 'Windows Device';
    return 'Unknown Device';
  }

  String _getOSName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    return 'Unknown OS';
  }
}
