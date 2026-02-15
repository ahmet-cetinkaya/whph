import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class ListGroupHeader extends StatelessWidget {
  final String title;
  final Widget? actions;
  final VoidCallback? onTap;
  final bool isExpanded;

  const ListGroupHeader({
    super.key,
    required this.title,
    this.actions,
    this.onTap,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget header = SectionHeader(
      title: title,
      trailing: Row(
        children: [
          const Expanded(child: Divider()),
          if (actions != null) ...[
            const SizedBox(width: AppTheme.sizeSmall),
            Flexible(child: actions!),
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppTheme.sizeSmall),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ],
      ),
      expandTrailing: true,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
          child: header,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
      child: header,
    );
  }
}
