import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class SyncDevicesTile extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  SyncDevicesTile({super.key});

  void _showSyncDevicesModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      title: _translationService.translate(SettingsTranslationKeys.syncDevicesTitle),
      maxHeightRatio: 0.4,
      maxWidthRatio: 0.6,
      child: const SyncDevicesPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsMenuTile(
      icon: Icons.sync,
      title: _translationService.translate(SettingsTranslationKeys.syncDevicesTitle),
      onTap: () => _showSyncDevicesModal(context),
    );
  }
}
