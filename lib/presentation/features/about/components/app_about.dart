import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AppAbout extends StatelessWidget {
  const AppAbout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage(AppInfo.logoPath),
              width: 100,
              height: 100,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppInfo.name,
                    style: AppTheme.headlineMedium,
                  ),
                  Text(
                    'Version ${AppInfo.version}',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            AppInfo.description,
            style: AppTheme.bodyMedium,
          ),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildExternalLink(title: 'Website', icon: Icons.web, url: AppInfo.websiteUrl),
                _buildExternalLink(title: 'Source Code', icon: Icons.code, url: AppInfo.sourceCodeUrl),
              ],
            )),
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
