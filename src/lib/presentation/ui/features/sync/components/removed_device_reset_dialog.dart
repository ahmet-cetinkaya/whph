import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Asks a device that the group removed whether it resets its sync identity
/// so it can pair again.
class RemovedDeviceResetDialog extends StatelessWidget {
  const RemovedDeviceResetDialog({super.key});

  /// `true` when the user confirms; closing the dialog counts as cancel.
  static Future<bool> show(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RemovedDeviceResetDialog(),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return AlertDialog(
      title: Text(translationService.translate(SyncTranslationKeys.pairingRemovedDeviceTitle)),
      content: Text(translationService.translate(SyncTranslationKeys.pairingRemovedDeviceDescription)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translationService.translate(SyncTranslationKeys.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(translationService.translate(SyncTranslationKeys.pairingRemovedDeviceConfirm)),
        ),
      ],
    );
  }
}
