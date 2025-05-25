import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// A reusable Markdown editor component that wraps the `markdown_editor_plus` package's
/// `MarkdownAutoPreview` component with consistent styling and behavior across the app.
class MarkdownEditor extends StatelessWidget {
  /// The text controller for the Markdown editor
  final TextEditingController controller;

  /// Called when the content changes
  final void Function(String)? onChanged;

  /// Hint text displayed when the editor is empty
  final String? hintText;

  /// Initial text to display in the editor (only used if controller is not provided)
  final String? initialText;

  /// Additional style to apply to the editor (optional)
  final TextStyle? style;

  /// Background color for the toolbar
  final Color? toolbarBackground;

  final ITranslationService _translationService;

  /// Creates a new [MarkdownEditor] instance
  MarkdownEditor(
      {super.key,
      required this.controller,
      this.onChanged,
      this.hintText,
      this.initialText,
      this.style,
      this.toolbarBackground,
      ITranslationService? translationService})
      : _translationService = translationService ?? container.resolve();

  /// Creates a [MarkdownEditor] with a default controller
  factory MarkdownEditor.withDefaultController({
    Key? key,
    String? initialText,
    void Function(String)? onChanged,
    String? hintText,
    TextStyle? style,
    ITranslationService? translationService,
  }) {
    translationService ??= container.resolve();

    return MarkdownEditor(
      key: key,
      controller: TextEditingController(text: initialText),
      onChanged: onChanged,
      hintText: hintText ?? translationService!.translate(SharedTranslationKeys.markdownEditorHint),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownAutoPreview(
      controller: controller,
      onChanged: onChanged,
      hintText: hintText ?? _translationService.translate(SharedTranslationKeys.markdownEditorHint),
      style: style,
      toolbarBackground: toolbarBackground ?? AppTheme.surface0,
    );
  }
}
