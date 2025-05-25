import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

/// A reusable Markdown rendering component that wraps the `markdown_editor_plus` package's
/// `MarkdownParse` component with consistent styling and behavior across the app.
class MarkdownRenderer extends StatelessWidget {
  /// The Markdown content to be rendered
  final String data;

  /// Creates a new [MarkdownRenderer] instance
  const MarkdownRenderer({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MarkdownParse(
      data: data,
      bulletBuilder: (params) {
        return Text(
          "•",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSizeLarge,
          ),
        );
      },
    );
  }
}
