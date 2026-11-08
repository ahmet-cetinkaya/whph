import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Shows the code both devices display (SAS) so the users can compare it. It
/// is the same dialog on the inviting and the joining device.
class PairingCodeDialog extends StatelessWidget {
  final String code;
  final String peerName;

  const PairingCodeDialog({super.key, required this.code, required this.peerName});

  /// `true` when the user says the codes match; closing the dialog counts as a mismatch.
  static Future<bool> show(BuildContext context, {required String code, required String peerName}) async {
    final matches = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PairingCodeDialog(code: code, peerName: peerName),
    );
    return matches ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(translationService.translate(SyncTranslationKeys.pairingCodeTitle)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            translationService.translate(SyncTranslationKeys.pairingCodeDescription, namedArgs: {'device': peerName}),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.sizeLarge),
          Text(
            code,
            key: const ValueKey('pairing-code'),
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translationService.translate(SyncTranslationKeys.pairingCodeMismatch)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(translationService.translate(SyncTranslationKeys.pairingCodeMatch)),
        ),
      ],
    );
  }
}
