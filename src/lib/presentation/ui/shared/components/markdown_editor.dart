import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:markdown_toolbar/markdown_toolbar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/main.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A reusable Markdown editor component that uses the `markdown_toolbar` package
/// with consistent styling and behavior across the app.
/// This includes a custom preview mode that supports link handling.
class MarkdownEditor extends StatefulWidget {
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

  /// Whether to enable link handling in preview mode
  final bool enableLinkHandling;

  /// Custom link handler (optional)
  final void Function(String text, String? href, String title)? onTapLink;

  /// Height of the editor (optional, defaults to 300 for single mode, 400 for tabbed mode)
  final double? height;

  /// Creates a new [MarkdownEditor] instance
  const MarkdownEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText,
    this.initialText,
    this.style,
    this.toolbarBackground,
    this.enableLinkHandling = true,
    this.onTapLink,
    this.height,
  });

  /// Creates a [MarkdownEditor] with a default controller
  factory MarkdownEditor.withDefaultController({
    Key? key,
    String? initialText,
    void Function(String)? onChanged,
    String? hintText,
    TextStyle? style,
    bool enableLinkHandling = true,
    void Function(String text, String? href, String title)? onTapLink,
    double? height,
    ITranslationService? translationService,
  }) {
    translationService ??= container.resolve<ITranslationService>();

    return MarkdownEditor(
      key: key,
      controller: TextEditingController(text: initialText),
      onChanged: onChanged,
      hintText: hintText ?? translationService.translate(SharedTranslationKeys.markdownEditorHint),
      style: style,
      enableLinkHandling: enableLinkHandling,
      onTapLink: onTapLink,
      height: height,
    );
  }

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  late final FocusNode _focusNode;
  bool _isPreviewMode = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Set initial mode based on content existence
    _isPreviewMode = widget.controller.text.isNotEmpty;

    // Add listener to update UI when text changes, but defer to avoid initial conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          widget.controller.addListener(_onTextChanged);
          setState(() {
            _isInitializing = false;
          });
        } catch (e) {
          // Handle controller errors gracefully
          setState(() {
            _isInitializing = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    try {
      widget.controller.removeListener(_onTextChanged);
    } catch (e) {
      // Listener may have already been removed or controller disposed
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Skip processing during initialization to prevent conflicts with paste operations
    if (_isInitializing || !mounted) return;

    try {
      // Trigger onChanged callback if provided
      if (widget.onChanged != null) {
        widget.onChanged!(widget.controller.text);
      }

      // Update UI if needed - defer to avoid conflicts with ongoing input operations
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } catch (e) {
      // Handle errors gracefully to prevent widget crashes
    }
  }

  void _togglePreviewMode() {
    if (!mounted) return;

    try {
      setState(() {
        _isPreviewMode = !_isPreviewMode;
      });

      // Ensure focus is properly managed when switching modes
      if (!_isPreviewMode && _focusNode.canRequestFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusNode.canRequestFocus) {
            _focusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      // Handle state update errors gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarBgColor = widget.toolbarBackground ?? theme.cardTheme.color ?? theme.colorScheme.surface;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.height ?? 400,
      ),
      child: Column(
        children: [
          // Toolbar Section (only show in editor mode)
          if (!_isPreviewMode)
            Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Row(
                children: [
                  // Markdown Toolbar
                  Expanded(
                    child: (defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS)
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: MarkdownToolbar(
                              controller: widget.controller,
                              useIncludedTextField: false,
                              focusNode: _focusNode,
                              // Style
                              collapsable: false,
                              backgroundColor: toolbarBgColor,
                              borderRadius: BorderRadius.circular(8),
                              iconColor: theme.colorScheme.primary,
                              iconSize: 20,
                              dropdownTextColor: theme.colorScheme.primary,
                              width: 36,
                              height: 36,
                              spacing: 4,
                              runSpacing: 4,
                              // Customize toolbar tooltips
                              showTooltips: true,
                              imageTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorImageTooltip),
                              headingTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorHeadingTooltip),
                              checkboxTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorCheckboxTooltip),
                              boldTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorBoldTooltip),
                              italicTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorItalicTooltip),
                              strikethroughTooltip: _translationService
                                  .translate(SharedTranslationKeys.markdownEditorStrikethroughTooltip),
                              linkTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorLinkTooltip),
                              codeTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorCodeTooltip),
                              bulletedListTooltip: _translationService
                                  .translate(SharedTranslationKeys.markdownEditorBulletedListTooltip),
                              numberedListTooltip: _translationService
                                  .translate(SharedTranslationKeys.markdownEditorNumberedListTooltip),
                              quoteTooltip:
                                  _translationService.translate(SharedTranslationKeys.markdownEditorQuoteTooltip),
                              horizontalRuleTooltip: _translationService
                                  .translate(SharedTranslationKeys.markdownEditorHorizontalRuleTooltip),
                            ),
                          )
                        : MarkdownToolbar(
                            controller: widget.controller,
                            useIncludedTextField: false,
                            focusNode: _focusNode,
                            // Style
                            collapsable: false,
                            backgroundColor: toolbarBgColor,
                            borderRadius: BorderRadius.circular(8),
                            iconColor: theme.colorScheme.primary,
                            iconSize: 20,
                            dropdownTextColor: theme.colorScheme.primary,
                            width: 36,
                            height: 36,
                            spacing: 4,
                            runSpacing: 4,
                            // Customize toolbar tooltips
                            showTooltips: true,
                            imageTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorImageTooltip),
                            headingTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorHeadingTooltip),
                            checkboxTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorCheckboxTooltip),
                            boldTooltip: _translationService.translate(SharedTranslationKeys.markdownEditorBoldTooltip),
                            italicTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorItalicTooltip),
                            strikethroughTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorStrikethroughTooltip),
                            linkTooltip: _translationService.translate(SharedTranslationKeys.markdownEditorLinkTooltip),
                            codeTooltip: _translationService.translate(SharedTranslationKeys.markdownEditorCodeTooltip),
                            bulletedListTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorBulletedListTooltip),
                            numberedListTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorNumberedListTooltip),
                            quoteTooltip:
                                _translationService.translate(SharedTranslationKeys.markdownEditorQuoteTooltip),
                            horizontalRuleTooltip: _translationService
                                .translate(SharedTranslationKeys.markdownEditorHorizontalRuleTooltip),
                          ),
                  ),
                  // Preview Toggle Button
                  Container(
                    margin: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: Icon(
                        _isPreviewMode ? Icons.edit : Icons.visibility,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      onPressed: _togglePreviewMode,
                      tooltip: _isPreviewMode
                          ? _translationService.translate(SharedTranslationKeys.markdownEditorEditTooltip)
                          : _translationService.translate(SharedTranslationKeys.markdownEditorPreviewTooltip),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Editor/Preview Section
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Stack(
                children: [
                  _isPreviewMode ? _buildPreviewTab() : _buildEditorTab(),
                  // Preview Toggle Button (only show in preview mode)
                  if (_isPreviewMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          onPressed: _togglePreviewMode,
                          tooltip: _translationService.translate(SharedTranslationKeys.markdownEditorEditTooltip),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    final theme = Theme.of(context);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      style: widget.style ??
          theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: widget.hintText ?? _translationService.translate(SharedTranslationKeys.markdownEditorHint),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
        filled: false,
      ),
      // Ensure proper focus management for paste operations
      onTap: () {
        try {
          if (mounted && _focusNode.canRequestFocus && !_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        } catch (e) {
          // Handle focus errors gracefully
        }
      },
      // Add robust error handling for input operations
      onChanged: (value) {
        try {
          // Allow normal text change processing
          // The _onTextChanged listener will handle the update
        } catch (e) {
          // Handle input errors gracefully
        }
      },
    );
  }

  Widget _buildPreviewTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) {
          // Safely handle controller value
          final text = value.text;
          final displayText = text.isEmpty
              ? (widget.hintText ?? _translationService.translate(SharedTranslationKeys.markdownEditorHint))
              : text;

          return Markdown(
            data: displayText,
            onTapLink: widget.enableLinkHandling ? (widget.onTapLink ?? _handleLinkTap) : null,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium?.copyWith(
                color: text.isEmpty ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.colorScheme.onSurface,
                height: 1.5,
              ),
              h1: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeXXLarge,
              ),
              h2: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeXLarge,
              ),
              h3: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeLarge,
              ),
              h4: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeMedium,
              ),
              h5: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeSmall,
              ),
              h6: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: AppTheme.fontSizeXSmall,
              ),
              a: TextStyle(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              code: TextStyle(
                backgroundColor: theme.colorScheme.surfaceContainer,
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
                fontSize: AppTheme.fontSizeSmall,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              listBullet: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                color: theme.colorScheme.onSurface,
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              blockquoteDecoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              tableHead: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              tableBody: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
              tableBorder: TableBorder.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 1,
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              ),
              tableHeadAlign: TextAlign.left,
              tableCellsPadding: const EdgeInsets.all(AppTheme.sizeSmall),
              tableColumnWidth: const FlexColumnWidth(),
            ),
          );
        },
      ),
    );
  }

  /// Default link handler that opens external links
  void _handleLinkTap(String text, String? href, String title) {
    if (href != null && href.isNotEmpty) {
      _launchUrl(href);
    }
  }

  /// Launches the provided URL using the url_launcher package
  void _launchUrl(String url) async {
    try {
      if (url.isEmpty) return;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Logger.error('Could not launch $url');
      }
    } catch (e) {
      Logger.error('Error launching URL $url: $e');
    }
  }
}
