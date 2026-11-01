import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/components/pairing_qr_view.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:acore/acore.dart' hide Container;

/// Dialog that shows this device's pairing invitation as a QR code
class SyncConnectInfoDialog extends StatelessWidget {
  final VoidCallback? onPaired;

  const SyncConnectInfoDialog({super.key, this.onPaired});

  /// Static method to show the dialog from anywhere
  static Future<void> show(BuildContext context, {VoidCallback? onPaired}) async {
    await ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: SyncConnectInfoDialog(onPaired: onPaired),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(translationService.translate(SyncTranslationKeys.connectInfoDialogTitle)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PairingQrView(onPaired: onPaired),
    );
  }
}
