import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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
                        'about.app_about.version',
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
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _translationService.translate('about.app_about.description'),
            style: AppTheme.bodyMedium,
          ),
        ),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildExternalLink(
                title: _translationService.translate('about.app_about.links.website'),
                icon: Icons.web,
                url: AppInfo.websiteUrl,
              ),
              _buildExternalLink(
                title: _translationService.translate('about.app_about.links.source_code'),
                icon: Icons.code,
                url: AppInfo.sourceCodeUrl,
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
      label: Text(title, style: AppTheme.bodyLarge),
      icon: Icon(icon),
    );
  }
}
