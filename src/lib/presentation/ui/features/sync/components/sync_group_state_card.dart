import 'package:flutter/material.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/presentation/ui/features/sync/components/needs_repairing_card.dart';
import 'package:whph/presentation/ui/features/sync/components/removed_from_group_card.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// The card the sync devices page shows for the device's standing in its group:
/// one for being removed, one for needing to be paired again, none otherwise.
class SyncGroupStateCard extends StatelessWidget {
  final SyncGroupState groupState;
  final VoidCallback onPair;

  const SyncGroupStateCard({super.key, required this.groupState, required this.onPair});

  @override
  Widget build(BuildContext context) {
    final card = switch (groupState) {
      SyncGroupState.removedFromGroup => RemovedFromGroupCard(onPair: onPair),
      SyncGroupState.needsRepairing => NeedsRepairingCard(onPair: onPair),
      SyncGroupState.ungrouped || SyncGroupState.member => null,
    };
    if (card == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium), child: card);
  }
}
