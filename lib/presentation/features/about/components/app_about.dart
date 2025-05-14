import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/about/constants/about_translation_keys.dart';

class AppAbout extends StatelessWidget {
  AppAbout({super.key});

  final ITranslationService _translationService = container.resolve<ITranslationService>();

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
                      "${AppInfo.shortName} (${AppInfo.name})",
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
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
              ],
            ),
          ),
        ),
        Text(
          _translationService.translate(AboutTranslationKeys.description),
          style: AppTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildExternalLink({required String title, required String url, required IconData icon}) {
    return TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      label: Text(title, style: AppTheme.bodyLarge),
      icon: Icon(icon),
    );
  }
}
