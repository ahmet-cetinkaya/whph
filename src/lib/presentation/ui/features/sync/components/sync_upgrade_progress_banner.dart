import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_upgrade_progress_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Progress of the post-upgrade preparation (D17) as a percentage. The job
/// reports only its phase (the cursor inside a phase is opaque), so progress
/// moves in phase steps.
int syncUpgradePercent(SyncUpgradePhase phase) => switch (phase) {
      SyncUpgradePhase.dedupe => 0,
      SyncUpgradePhase.bootstrap => 33,
      SyncUpgradePhase.reauthor => 66,
      SyncUpgradePhase.done => 100,
    };

/// "Preparing sync data… N%" while the upgrade job runs; nothing once it is done.
class SyncUpgradeProgressBanner extends StatefulWidget {
  static const Duration defaultPollInterval = Duration(seconds: 2);

  final Mediator? mediator;
  final Duration pollInterval;

  const SyncUpgradeProgressBanner({super.key, this.mediator, this.pollInterval = defaultPollInterval});

  @override
  State<SyncUpgradeProgressBanner> createState() => _SyncUpgradeProgressBannerState();
}

class _SyncUpgradeProgressBannerState extends State<SyncUpgradeProgressBanner> {
  final _translationService = container.resolve<ITranslationService>();
  late final Mediator _mediator = widget.mediator ?? container.resolve<Mediator>();
  Timer? _poller;
  SyncUpgradeProgress? _progress;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final progress = await _mediator.send<GetSyncUpgradeProgressQuery, SyncUpgradeProgress>(
        GetSyncUpgradeProgressQuery(),
      );
      if (!mounted) return;
      if (progress.isDone) _poller?.cancel();
      setState(() => _progress = progress);
    } catch (error) {
      Logger.error('SyncUpgradeProgressBanner: reading the upgrade progress failed: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null || progress.isDone) return const SizedBox.shrink();

    final percent = syncUpgradePercent(progress.phase);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _translationService.translate(SyncTranslationKeys.upgradeProgress, namedArgs: {'percent': '$percent'}),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          LinearProgressIndicator(value: percent / 100),
        ],
      ),
    );
  }
}
