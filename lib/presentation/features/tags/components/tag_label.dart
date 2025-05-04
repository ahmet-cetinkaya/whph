import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class TagLabel extends StatelessWidget {
  final String? tagColor;
  final String tagName;
  final bool mini;
  final TextOverflow overflow;

  const TagLabel({
    super.key,
    this.tagColor,
    required this.tagName,
    this.mini = false,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final color = tagColor != null ? Color(int.parse('FF$tagColor', radix: 16)) : Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.label_outline,
          size: mini ? AppTheme.fontSizeSmall : AppTheme.fontSizeMedium,
          color: color,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            tagName,
            style: (mini ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
              color: color,
            ),
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}
