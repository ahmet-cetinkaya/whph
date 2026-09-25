import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/components/mcp_settings.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';
import 'package:whph/main.dart';

class McpSettingsDialog extends StatelessWidget {
  const McpSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.aiTitle),
      showBackButton: true,
      hideSidebar: true,
      showLogo: false,
      builder: (context) => McpSettings(
        accessService: container.resolve<IMcpAccessService>(),
        runtimeService: container.resolve<McpRuntimeService>(),
        translationService: translationService,
        operationService: container.resolve<IMcpOperationService>(),
      ),
    );
  }
}
