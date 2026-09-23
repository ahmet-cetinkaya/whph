import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/components/mcp_settings_dialog.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class AiSettingsTile extends StatelessWidget {
  const AiSettingsTile({super.key});

  void _showAiSettings(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const McpSettingsDialog(),
      size: DialogSize.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return SettingsMenuTile(
      icon: Icons.smart_toy_outlined,
      title: translationService.translate(SettingsTranslationKeys.aiTitle),
      subtitle: translationService.translate(SettingsTranslationKeys.mcpDescription),
      onTap: () => _showAiSettings(context),
      isActive: true,
    );
  }
}