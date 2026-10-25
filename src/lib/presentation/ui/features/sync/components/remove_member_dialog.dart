import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Confirms removing a device. Removal is group-wide (FR-026), so the text says
/// so before the user agrees.
class RemoveMemberDialog extends StatelessWidget {
  final String deviceName;

  const RemoveMemberDialog({super.key, required this.deviceName});

  /// `true` when the user confirms; closing the dialog counts as cancel.
  static Future<bool> confirm(BuildContext context, {required String deviceName}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => RemoveMemberDialog(deviceName: deviceName),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final namedArgs = {'device': deviceName};

    return AlertDialog(
      title: Text(translationService.translate(SyncTranslationKeys.removeMemberTitle, namedArgs: namedArgs)),
      content: Text(translationService.translate(SyncTranslationKeys.removeMemberDescription, namedArgs: namedArgs)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(translationService.translate(SyncTranslationKeys.cancel)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(translationService.translate(SyncTranslationKeys.removeMemberAction)),
        ),
      ],
    );
  }
}
