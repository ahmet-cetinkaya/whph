import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/features/settings/components/settings_menu_tile.dart';
import 'package:whph/features/settings/pages/permissions_page.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class PermissionSettings extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  PermissionSettings({super.key});

  void _showPermissionsModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.max,
      child: const PermissionsPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!PlatformUtils.isMobile) return const SizedBox.shrink();

    return SettingsMenuTile(
      icon: Icons.security,
      title: _translationService.translate(SettingsTranslationKeys.permissionsTitle),
      onTap: () => _showPermissionsModal(context),
      isActive: true,
    );
  }
}
