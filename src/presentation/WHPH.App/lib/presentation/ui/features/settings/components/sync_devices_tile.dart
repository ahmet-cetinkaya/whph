import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/sync_devices_page.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class SyncDevicesTile extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  SyncDevicesTile({super.key});

  void _showSyncDevicesModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const SyncDevicesPage(),
      size: DialogSize.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsMenuTile(
      icon: Icons.sync,
      title: _translationService.translate(SettingsTranslationKeys.syncDevicesTitle),
      onTap: () => _showSyncDevicesModal(context),
      isActive: true,
    );
  }
}
