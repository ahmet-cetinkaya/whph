import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import '../constants/shared_translation_keys.dart';

class RegexHelpDialog extends StatelessWidget {
  const RegexHelpDialog({super.key});

  static void show(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const RegexHelpDialog(),
      size: DialogSize.xLarge,
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

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          translationService.translate(SharedTranslationKeys.regexHelpTitle),
          style: AppTheme.headlineSmall,
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: translationService.translate(SharedTranslationKeys.backButton),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.sizeSmall),
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
      ),
    );
  }
}
