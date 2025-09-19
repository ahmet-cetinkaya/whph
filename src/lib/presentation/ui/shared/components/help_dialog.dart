import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/markdown_renderer.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class HelpDialog extends StatelessWidget {
  final String titleKey;
  final String markdownContentKey;

  final _translationService = container.resolve<ITranslationService>();

  HelpDialog({
    super.key,
    required this.titleKey,
    required this.markdownContentKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(_translationService.translate(titleKey)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: MarkdownRenderer(
          data: _translationService.translate(markdownContentKey),
        ),
      ),
    );
  }
}
