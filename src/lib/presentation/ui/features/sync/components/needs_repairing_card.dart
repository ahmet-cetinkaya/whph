import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Shown when a restore from an older backup (or a lost key file) left this
/// device's membership rows behind (D14): the group no longer recognises it, so
/// it does not sync until it is paired again.
class NeedsRepairingCard extends StatelessWidget {
  final VoidCallback onPair;

  const NeedsRepairingCard({super.key, required this.onPair});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return InformationCard.themed(
      context: context,
      icon: Icons.sync_problem,
      text: '${translationService.translate(SyncTranslationKeys.needsRepairingTitle)}\n'
          '${translationService.translate(SyncTranslationKeys.needsRepairingDescription)}',
      action: TextButton(
        onPressed: onPair,
        child: Text(translationService.translate(SyncTranslationKeys.addDeviceTooltip)),
      ),
    );
  }
}
