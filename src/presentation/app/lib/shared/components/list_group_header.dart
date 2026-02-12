import 'package:flutter/material.dart';
import 'package:whph/shared/components/section_header.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class ListGroupHeader extends StatelessWidget {
  final String title;
  final bool shouldTranslate;

  const ListGroupHeader({
    super.key,
    required this.title,
    this.shouldTranslate = true,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
      child: SectionHeader(
        title: displayTitle,
        trailing: const Divider(),
        expandTrailing: true,
      ),
    );
  }
}
