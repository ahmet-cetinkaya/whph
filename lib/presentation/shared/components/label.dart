import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

/// A general-purpose label component that can display a single label or multiple labels.
///
/// This component can be used for tags, categories, or any other label-type UI element
/// that requires an icon followed by text. It supports both single and multiple values
/// with comma separation when displaying multiple labels.
class Label extends StatelessWidget {
  /// The icon to display before the label text
  final IconData icon;

  /// The color for the icon and text
  final Color? color;

  /// For single label display: the text to show
  final String text;

  /// For multiple label display: the texts to show as comma-separated values
  final List<String>? texts;

  /// For multiple label display: optional colors for each text value
  final List<Color>? valueColors;

  /// Whether to use smaller text and icon sizes
  final bool mini;

  /// How to handle text overflow
  final TextOverflow overflow;

  /// Creates a label with a single text value.
  ///
  /// Use this constructor for displaying a single label.
  const Label.single({
    super.key,
    required this.icon,
    this.color,
    required this.text,
    this.mini = false,
    this.overflow = TextOverflow.ellipsis,
  })  : texts = null,
        valueColors = null;

  /// Creates a label with multiple text values that will be joined with commas.
  ///
  /// Use this constructor for displaying multiple labels with a single icon.
  /// All values will use the same color provided in [color] parameter.
  const Label.multiple({
    super.key,
    required this.icon,
    this.color,
    required List<String> values,
    this.mini = false,
    this.overflow = TextOverflow.ellipsis,
  })  : text = '',
        texts = values,
        valueColors = null;

  /// Creates a label with multiple text values where each value has its own color.
  ///
  /// Use this constructor for displaying multiple labels with individual colors.
  /// The icon will use the color provided in the [color] parameter.
  /// If [valueColors] has fewer items than [values], remaining values will use the [color].
  const Label.multipleColored({
    super.key,
    required this.icon,
    this.color,
    required List<String> values,
    required List<Color> colors,
    this.mini = false,
    this.overflow = TextOverflow.ellipsis,
  })  : text = '',
        texts = values,
        valueColors = colors;

  @override
  Widget build(BuildContext context) {
    final defaultColor = color ?? Theme.of(context).primaryColor;
    final iconSize = mini ? AppTheme.fontSizeSmall : AppTheme.fontSizeMedium;
    final baseTextStyle = mini ? AppTheme.bodySmall : AppTheme.bodyMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeXSmall / 1.6),
          child: Icon(
            icon,
            size: iconSize,
            color: defaultColor,
          ),
        ),
        const SizedBox(width: AppTheme.sizeXSmall),
        Flexible(
          child: texts != null && valueColors != null
              ? _buildRichText(context, baseTextStyle, defaultColor)
              : Text(
                  texts != null ? texts!.join(', ') : text,
                  style: baseTextStyle.copyWith(color: defaultColor),
                  overflow: overflow,
                ),
        ),
      ],
    );
  }

  /// Builds a RichText widget with individual colors for each value.
  Widget _buildRichText(BuildContext context, TextStyle baseStyle, Color defaultColor) {
    final List<InlineSpan> spans = [];

    for (int i = 0; i < texts!.length; i++) {
      // Add comma and space before all but the first item
      if (i > 0) {
        spans.add(TextSpan(
          text: ', ',
          style: baseStyle.copyWith(color: defaultColor),
        ));
      }

      // Add the text with its color
      Color valueColor = defaultColor;
      if (valueColors != null && i < valueColors!.length) {
        valueColor = valueColors![i];
      }

      spans.add(TextSpan(
        text: texts![i],
        style: baseStyle.copyWith(color: valueColor),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: overflow,
    );
  }
}
