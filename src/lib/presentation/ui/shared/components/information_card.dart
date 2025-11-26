import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show ColorContrastHelper;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// A reusable information card component that displays contextual help text
/// Used across various dialogs to provide consistent styling and layout
class InformationCard extends StatelessWidget {
  final IconData icon;
  final String text;
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
    TextStyle? textStyle,
  }) {
    final theme = Theme.of(context);
    return InformationCard(
      icon: icon,
      text: text,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      iconColor: ColorContrastHelper.getContrastingTextColor(theme.colorScheme.surfaceContainerHighest),
      textColor: ColorContrastHelper.getContrastingTextColor(theme.colorScheme.surfaceContainerHighest),
      textStyle: textStyle ?? theme.textTheme.bodySmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: border ?? Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ??
                ColorContrastHelper.getContrastingTextColor(
                  backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
          ),
          SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: Text(
              text,
              style: textStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor ??
                            ColorContrastHelper.getContrastingTextColor(
                              backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
