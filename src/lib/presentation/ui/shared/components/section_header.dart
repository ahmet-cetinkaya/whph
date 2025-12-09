import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// A reusable section header component that provides a consistent
/// look and feel for section headers throughout the application.
///
/// Features:
/// - Optional icon with proper spacing
/// - Customizable title style
/// - Optional trailing widget (e.g., button, switch)
/// - Optional tap handler for interactive headers
/// - Configurable padding
/// - Proper accessibility support
class SectionHeader extends StatelessWidget {
  /// The title text displayed in the header
  final String title;

  /// Optional icon to display before the title
  final IconData? icon;

  /// Optional widget to display on the right side (e.g., "See all" button)
  final Widget? trailing;

  /// Optional callback when the header is tapped
  final VoidCallback? onTap;

  /// Custom padding for the header. Defaults to horizontal small padding
  final EdgeInsetsGeometry? padding;

  /// Custom text style for the title. Defaults to theme's titleSmall
  final TextStyle? titleStyle;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.onTap,
    this.padding,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppTheme.iconSizeMedium,
                color: Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: AppTheme.sizeSmall),
            ],
            Flexible(
              child: Text(
                title,
                style: titleStyle ?? Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.sizeSmall),
          trailing!,
        ],
      ],
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
        child: content,
      );
    }

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
      child: content,
    );
  }
}
