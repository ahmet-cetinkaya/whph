import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class HelpMenu extends StatelessWidget {
  final String titleKey;
  final String markdownContentKey;

  final _translationService = container.resolve<ITranslationService>();

  HelpMenu({
    super.key,
    required this.titleKey,
    required this.markdownContentKey,
  });

  void _showHelpModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(AppTheme.sizeXLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _translationService.translate(titleKey),
                        style: AppTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.sizeLarge),
              Expanded(
                child: MarkdownParse(
                  data: _translationService.translate(markdownContentKey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.help_outline),
        onPressed: () => _showHelpModal(context),
        color: AppTheme.primaryColor,
        tooltip: _translationService.translate(SharedTranslationKeys.helpTooltip));
  }
}
