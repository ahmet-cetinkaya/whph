import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/markdown_renderer.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class HelpMenu extends StatelessWidget {
  final String titleKey;
  final String markdownContentKey;

  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  HelpMenu({
    super.key,
    required this.titleKey,
    required this.markdownContentKey,
  });

  /// Static method to show help modal from anywhere
  static void showHelpModal({
    required BuildContext context,
    required String titleKey,
    required String markdownContentKey,
  }) {
    final translationService = container.resolve<ITranslationService>();
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.medium,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(translationService.translate(titleKey)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: MarkdownRenderer(
            data: translationService.translate(markdownContentKey),
          ),
        ),
      ),
    );
  }

  void _showHelpModal(BuildContext context) {
    showHelpModal(
      context: context,
      titleKey: titleKey,
      markdownContentKey: markdownContentKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: const Icon(SharedUiConstants.helpIcon),
        onPressed: () => _showHelpModal(context),
        color: _themeService.primaryColor,
        tooltip: _translationService.translate(SharedTranslationKeys.helpTooltip));
  }
}
