import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/settings/components/debug_logs_content.dart';

class DebugLogsDialog extends StatelessWidget {
  const DebugLogsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return AlertDialog(
      title: Text(translationService.translate(SettingsTranslationKeys.debugLogsPageTitle)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: const DebugLogsContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translationService.translate(SettingsTranslationKeys.commonCancel)),
        ),
      ],
    );
  }
}
