import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/about/constants/about_translation_keys.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Dialog that displays the changelog for a new version
class ChangelogDialog extends StatelessWidget {
  final ChangelogEntry changelogEntry;

  ChangelogDialog({
    super.key,
    required this.changelogEntry,
  });

  final ITranslationService _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(AboutTranslationKeys.changelogTitle),
          style: AppTheme.headlineSmall,
        ),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _translationService.translate(AboutTranslationKeys.changelogCloseButton),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              const Image(
                image: AssetImage(AppInfo.logoPath),
                width: 80,
                height: 80,
              ),
              const SizedBox(height: AppTheme.sizeMedium),

              // App name
              Text(
                AppInfo.name,
                style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold),
              ),

              // Version
              Text(
                _translationService.translate(
                  AboutTranslationKeys.version,
                  namedArgs: {'version': changelogEntry.version},
                ),
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
              ),
              const SizedBox(height: AppTheme.sizeXLarge),

              // Changelog content - using MarkdownBody instead of Markdown to avoid unbounded height
              Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(
                  data: changelogEntry.content,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      _launchUrl(href);
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: AppTheme.fontSizeMedium,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    h1: TextStyle(
                      fontSize: AppTheme.fontSizeXXLarge,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    h2: TextStyle(
                      fontSize: AppTheme.fontSizeXLarge,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    h3: TextStyle(
                      fontSize: AppTheme.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    listBullet: TextStyle(
                      fontSize: AppTheme.fontSizeLarge,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    a: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sizeLarge),
            ],
          ),
        ),
      ),
    );
  }

  /// Launches the provided URL using the url_launcher package
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Logger.error('Could not launch $url');
    }
  }
}
