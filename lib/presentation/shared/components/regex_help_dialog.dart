import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class RegexHelpDialog extends StatelessWidget {
  const RegexHelpDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RegexHelpDialog(),
    );
  }

  Widget _buildPatternExample(BuildContext context, String pattern, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pattern,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }

  void _closeDialog(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return AlertDialog(
      title: Text(translationService.translate(SharedTranslationKeys.regexHelpTitle)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPatternExample(
              context,
              '.*Chrome.*',
              translationService.translate(SharedTranslationKeys.regexHelpExamplesChrome),
            ),
            _buildPatternExample(
              context,
              '.*Visual Studio Code.*',
              translationService.translate(SharedTranslationKeys.regexHelpExamplesVscode),
            ),
            _buildPatternExample(
              context,
              '^Chrome\$',
              translationService.translate(SharedTranslationKeys.regexHelpExamplesExactChrome),
            ),
            _buildPatternExample(
              context,
              'Slack|Discord',
              translationService.translate(SharedTranslationKeys.regexHelpExamplesChat),
            ),
            _buildPatternExample(
              context,
              '.*\\.pdf',
              translationService.translate(SharedTranslationKeys.regexHelpExamplesPdf),
            ),
            const SizedBox(height: AppTheme.sizeLarge),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTips),
              style: AppTheme.bodyMedium,
            ),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTipAny),
              style: AppTheme.bodySmall,
            ),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTipStart),
              style: AppTheme.bodySmall,
            ),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTipEnd),
              style: AppTheme.bodySmall,
            ),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTipOr),
              style: AppTheme.bodySmall,
            ),
            Text(
              translationService.translate(SharedTranslationKeys.regexHelpTipDot),
              style: AppTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _closeDialog(context),
          child: Text(translationService.translate(SharedTranslationKeys.closeButton)),
        ),
      ],
    );
  }
}
