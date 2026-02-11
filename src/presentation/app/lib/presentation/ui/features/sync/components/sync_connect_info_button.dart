import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_connect_info_dialog.dart';
import 'package:whph/main.dart';

class SyncConnectInfoButton extends StatelessWidget {
  final _themeService = container.resolve<IThemeService>();

  SyncConnectInfoButton({super.key});

  /// Static method to show connection info modal from anywhere
  static Future<void> showConnectInfoModal(BuildContext context) async {
    await SyncConnectInfoDialog.show(context);
  }

  void _showConnectInfoModal(BuildContext context) {
    SyncConnectInfoButton.showConnectInfoModal(context);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      onPressed: () => _showConnectInfoModal(context),
      color: _themeService.primaryColor,
    );
  }
}
