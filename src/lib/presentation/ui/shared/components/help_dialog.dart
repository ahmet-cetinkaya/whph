import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/markdown_renderer.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class HelpDialog extends StatelessWidget {
  final String titleKey;
  final String markdownContentKey;
  final VoidCallback? onStartTour;
  final List<Widget>? appBarActions;

  final _translationService = container.resolve<ITranslationService>();

  HelpDialog({
    super.key,
    required this.titleKey,
    required this.markdownContentKey,
    this.onStartTour,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translationService.translate(SharedTranslationKeys.help)),
        actions: [
          if (onStartTour != null)
            TextButton.icon(
              icon: const Icon(Icons.tour),
              label: Text(_translationService.translate(SharedTranslationKeys.startTour)),
              onPressed: () => Navigator.of(context).pop('start_tour'),
            ),
          if (appBarActions != null) ...appBarActions!,
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: MarkdownRenderer(
          data: '# ${_translationService.translate(titleKey)}\n\n${_translationService.translate(markdownContentKey)}',
        ),
      ),
    );
  }
}
