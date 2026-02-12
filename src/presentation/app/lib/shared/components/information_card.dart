import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:acore/acore.dart' show ColorContrastHelper;
import 'package:whph/shared/constants/app_theme.dart';

/// A reusable information card component that displays contextual help text
/// Used across various dialogs to provide consistent styling and layout
class InformationCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isMarkdown;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final TextStyle? textStyle;

  const InformationCard({
    super.key,
    required this.icon,
    required this.text,
    this.isMarkdown = false,
    this.iconColor,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.textStyle,
  });

  /// Creates an information card with the default theme styling
  /// Used in most dialog contexts for consistent appearance
  factory InformationCard.themed({
    required BuildContext context,
    required IconData icon,
    required String text,
    bool isMarkdown = false,
    TextStyle? textStyle,
  }) {
    final theme = Theme.of(context);
    return InformationCard(
      icon: icon,
      text: text,
      isMarkdown: isMarkdown,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      iconColor: ColorContrastHelper.getContrastingTextColor(theme.colorScheme.surfaceContainerHighest),
      textColor: ColorContrastHelper.getContrastingTextColor(theme.colorScheme.surfaceContainerHighest),
      textStyle: textStyle ?? theme.textTheme.bodySmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ??
        ColorContrastHelper.getContrastingTextColor(
          backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        );

    return Container(
      padding: padding ?? EdgeInsets.all(AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: border ?? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? effectiveTextColor,
            ),
          ),
          SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: isMarkdown
                ? MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: textStyle ?? theme.textTheme.bodySmall?.copyWith(color: effectiveTextColor),
                      listBullet: theme.textTheme.bodySmall?.copyWith(color: effectiveTextColor),
                    ),
                  )
                : Text(
                    text,
                    style: textStyle ??
                        theme.textTheme.bodySmall?.copyWith(
                          color: effectiveTextColor,
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}
