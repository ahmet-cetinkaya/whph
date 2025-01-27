import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class HelpMenu extends StatelessWidget {
  final String titleKey;
  final String contentKey;

  const HelpMenu({
    super.key,
    required this.titleKey,
    required this.contentKey,
  });

  void _showHelpModal(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translationService.translate(titleKey),
                    style: AppTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: MarkdownParse(
                  data: translationService.translate(contentKey),
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
    );
  }
}
