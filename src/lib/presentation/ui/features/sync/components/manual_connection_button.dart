import 'package:flutter/material.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/presentation/ui/features/sync/components/manual_connection_dialog.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart';

class ManualConnectionButton extends StatelessWidget {
  final Function(DeviceInfo deviceInfo) onConnect;
  final _themeService = container.resolve<IThemeService>();
  final _translationService = container.resolve<ITranslationService>();

  ManualConnectionButton({
    super.key,
    required this.onConnect,
  });

  /// Static method to show manual connection dialog from anywhere
  static void showManualConnectionDialog(
    BuildContext context, {
    required Function(DeviceInfo deviceInfo) onConnect,
    VoidCallback? onCancel,
  }) async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.medium,
      child: ManualConnectionDialog(
        onConnect: onConnect,
        onCancel: onCancel,
      ),
    );

    // Handle the result if needed
    if (result == true) {
      // Connection was successful
    }
  }

  void _showManualConnectionDialog(BuildContext context) {
    ManualConnectionButton.showManualConnectionDialog(
      context,
      onConnect: onConnect,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.link),
      onPressed: () => _showManualConnectionDialog(context),
      color: _themeService.primaryColor,
      tooltip: _translationService.translate(SyncTranslationKeys.manualConnection),
    );
  }
}
