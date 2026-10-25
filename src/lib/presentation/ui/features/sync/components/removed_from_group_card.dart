import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Shown when another device removed this one from the sync group (D14). The
/// device no longer syncs until it is paired again.
class RemovedFromGroupCard extends StatelessWidget {
  final VoidCallback onPair;

  const RemovedFromGroupCard({super.key, required this.onPair});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return InformationCard.themed(
      context: context,
      icon: Icons.link_off,
      text: '${translationService.translate(SyncTranslationKeys.removedFromGroupTitle)}\n'
          '${translationService.translate(SyncTranslationKeys.removedFromGroupDescription)}',
      action: TextButton(
        onPressed: onPair,
        child: Text(translationService.translate(SyncTranslationKeys.addDeviceTooltip)),
      ),
    );
  }
}
