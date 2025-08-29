import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/features/settings/components/debug_logs_settings.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';

class AdvancedSettingsPage extends StatelessWidget {
  static const String route = '/settings/advanced';

  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.advancedSettingsTitle),
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: AppTheme.sizeSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [
                // Debug Logs Settings
                const DebugLogsSettings(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
