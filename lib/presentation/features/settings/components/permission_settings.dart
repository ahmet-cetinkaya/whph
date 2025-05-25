import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/features/settings/pages/permissions_page.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class PermissionSettings extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  PermissionSettings({super.key});

  void _showPermissionsModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      title: _translationService.translate(SettingsTranslationKeys.permissionsTitle),
      maxHeightRatio: 0.4,
      maxWidthRatio: 0.6,
      child: const PermissionsPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return SettingsMenuTile(
      icon: Icons.security,
      title: _translationService.translate(SettingsTranslationKeys.permissionsTitle),
      onTap: () => _showPermissionsModal(context),
    );
  }
}
