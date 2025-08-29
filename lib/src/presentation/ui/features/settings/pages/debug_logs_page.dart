import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/settings/components/debug_logs_content.dart';

class DebugLogsPage extends StatelessWidget {
  static const String route = '/settings/advanced/debug-logs';

  const DebugLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.debugLogsPageTitle),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              translationService.translate(SettingsTranslationKeys.debugLogsPageDescription),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),

          // Debug logs content
          const Expanded(
            child: DebugLogsContent(),
          ),
        ],
      ),
    );
  }
}
