import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/settings/pages/permissions_page.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class PermissionSettings extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  PermissionSettings({super.key});

  void _showPermissionsModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.large,
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
