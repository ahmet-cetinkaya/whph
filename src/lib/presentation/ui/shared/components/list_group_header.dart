import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class ListGroupHeader extends StatelessWidget {
  final String title;
  final bool shouldTranslate;
  final Widget? actions;
  final VoidCallback? onTap;
  final bool isExpanded;

  const ListGroupHeader({
    super.key,
    required this.title,
    this.shouldTranslate = true,
    this.actions,
    this.onTap,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    String displayTitle = title;

    if (shouldTranslate) {
      final translationService = container.resolve<ITranslationService>();
      // Attempt to translate the title if it's a key, otherwise show as is
      final translated = translationService.translate(title);
      if (translated.isNotEmpty && translated != title) {
        displayTitle = translated;
      }
    }

    Widget header = SectionHeader(
      title: displayTitle,
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
