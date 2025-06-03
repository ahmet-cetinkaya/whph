import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/components/markdown_renderer.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
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
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.medium,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_translationService.translate(titleKey)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: MarkdownRenderer(
            data: _translationService.translate(markdownContentKey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: const Icon(SharedUiConstants.helpIcon),
        onPressed: () => _showHelpModal(context),
        color: AppTheme.primaryColor,
        tooltip: _translationService.translate(SharedTranslationKeys.helpTooltip));
  }
}
