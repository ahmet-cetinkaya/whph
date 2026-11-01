import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Asks the joiner to confirm leaving its current sync group (D7) for the
/// group of [peerName].
class GroupSwitchDialog extends StatelessWidget {
  final String peerName;

  const GroupSwitchDialog({super.key, required this.peerName});

  /// `true` when the user confirms; closing the dialog counts as cancel.
  static Future<bool> show(BuildContext context, {required String peerName}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GroupSwitchDialog(peerName: peerName),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return AlertDialog(
      title: Text(translationService.translate(SyncTranslationKeys.pairingGroupSwitchTitle)),
      content: Text(
        translationService
            .translate(SyncTranslationKeys.pairingGroupSwitchDescription, namedArgs: {'device': peerName}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translationService.translate(SyncTranslationKeys.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(translationService.translate(SyncTranslationKeys.pairingGroupSwitchConfirm)),
        ),
      ],
    );
  }
}
