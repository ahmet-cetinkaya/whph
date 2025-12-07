import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
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
