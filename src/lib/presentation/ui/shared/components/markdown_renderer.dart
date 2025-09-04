import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// A reusable Markdown rendering component that wraps the `flutter_markdown` package's
/// `Markdown` component with consistent styling and behavior across the app.
class MarkdownRenderer extends StatelessWidget {
  /// The Markdown content to be rendered
  final String data;

  /// Creates a new [MarkdownRenderer] instance
  const MarkdownRenderer({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: data,
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
        h4: TextStyle(
          fontSize: AppTheme.fontSizeMedium,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h5: TextStyle(
          fontSize: AppTheme.fontSizeMedium,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h6: TextStyle(
          fontSize: AppTheme.fontSizeSmall,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        a: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        code: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.surface,
          color: Theme.of(context).colorScheme.onSurface,
          fontFamily: 'monospace',
          fontSize: AppTheme.fontSizeSmall,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        listBullet: TextStyle(
          fontSize: AppTheme.fontSizeLarge,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        blockquote: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
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
      // Handle error - could show a snackbar or log the error
      Logger.error('Could not launch $url');
    }
  }
}
