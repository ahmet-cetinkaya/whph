import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/about/constants/about_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';

class AppAbout extends StatelessWidget {
  AppAbout({super.key});

  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final ISetupService _setupService = container.resolve<ISetupService>();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppTheme.sizeLarge),
        // Logo and App Name
        const Image(
          image: AssetImage(AppInfo.logoPath),
          width: 80,
          height: 80,
        ),
        const SizedBox(height: AppTheme.sizeMedium),
        Text(
          AppInfo.name,
          style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          _translationService.translate(
            AboutTranslationKeys.version,
            namedArgs: {'version': AppInfo.version},
          ),
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: AppTheme.sizeXLarge),

        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
          child: Text(
            _translationService.translate(
              AboutTranslationKeys.description,
              namedArgs: {'appName': AppInfo.name},
            ),
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppTheme.sizeXLarge),

        // Links
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
          child: Column(
            children: [
              SettingsMenuTile(
                icon: Icons.language,
                title: _translationService.translate(AboutTranslationKeys.websiteLink),
                onTap: () => _launchUrl(AppInfo.websiteUrl),
                isActive: true,
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              SettingsMenuTile(
                icon: Icons.code,
                title: _translationService.translate(AboutTranslationKeys.sourceCodeLink),
                onTap: () => _launchUrl(AppInfo.sourceCodeUrl),
                isActive: true,
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              SettingsMenuTile(
                icon: Icons.feedback,
                title: _translationService.translate(AboutTranslationKeys.feedback),
                onTap: () => _handleFeedback(context),
                isActive: true,
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              SettingsMenuTile(
                icon: Icons.mail,
                title: _translationService.translate(AboutTranslationKeys.contact),
                onTap: () => _launchUrl('mailto:${AppInfo.supportEmail}'),
                isActive: true,
              ),
              if (PlatformUtils.isDesktop) ...[
                const SizedBox(height: AppTheme.sizeSmall),
                SettingsMenuTile(
                  icon: Icons.update,
                  title: _translationService.translate(AboutTranslationKeys.checkUpdate),
                  onTap: () => _setupService.checkForUpdates(context),
                  isActive: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sizeLarge),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Logger.error('Could not launch $url');
    }
  }

  Future<void> _handleFeedback(BuildContext context) async {
    final url = await _prepareFeedbackIssueUrl(context);
    await _launchUrl(url);
  }

  Future<String> _prepareFeedbackIssueUrl(BuildContext context) async {
    final deviceInfo = await _getDeviceInfo();

    // If the context is not mounted, return a default URL to avoid errors
    if (!context.mounted) return '${AppInfo.sourceCodeUrl}/issues/new';

    final screenSize = MediaQuery.sizeOf(context);
    final queryParams = <String, String>{
      'template': 'general_feedback.yml',
      'title': '[FEEDBACK] ',
      'app-version': AppInfo.version,
      'device-model': deviceInfo['deviceModel'] ?? 'Unknown',
      'operating-system': '${deviceInfo['osName']} ${deviceInfo['osVersion']}',
      'app-language': _translationService.getCurrentLanguage(context),
      'screen-size': '${screenSize.width.toInt()}x${screenSize.height.toInt()}',
    };

    final uri = Uri.parse('${AppInfo.sourceCodeUrl}/issues/new').replace(
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      if (PlatformUtils.isMobile) {
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
      Logger.error('Error getting device info: $e');
    }

    return {
      'deviceModel': _getBasicDeviceModel(),
      'osName': _getOSName(),
      'osVersion': Platform.operatingSystemVersion,
    };
  }

  String _getBasicDeviceModel() {
    if (PlatformUtils.isMobile) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isLinux) return 'Linux Device';
    if (Platform.isMacOS) return 'macOS Device';
    if (Platform.isWindows) return 'Windows Device';
    return 'Unknown Device';
  }

  String _getOSName() {
    if (PlatformUtils.isMobile) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    return 'Unknown OS';
  }
}
