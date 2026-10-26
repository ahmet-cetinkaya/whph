import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/sync_now_command.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Mixin that runs a manual sync with every paired device from the sync
/// devices page and keeps the outcome per device.
mixin SyncStatusMixin<T extends StatefulWidget> on State<T> {
  // Services to be provided by the implementing class
  Mediator get mediator;
  ITranslationService get translationService;

  // State accessors to be provided by implementing class
  AnimationController get syncButtonAnimationController;
  SyncStatus get currentSyncStatus;
  set currentSyncStatus(SyncStatus value);

  // Callback for refreshing device list
  Future<void> Function() get onRefresh;

  final Map<String, SyncState> _lastSyncResultByDeviceId = {};

  /// Outcome of the given device's most recent sync attempt in this app
  /// session, or null when it has not been synced since the app started.
  SyncState? lastSyncResultOf(String deviceId) => _lastSyncResultByDeviceId[deviceId];

  /// Syncs now with every paired device and shows the outcome.
  Future<void> runManualSync() async {
    if (currentSyncStatus.isSyncing) return;

    _showSyncStatus(const SyncStatus(state: SyncState.syncing, isManual: true));
    OverlayNotificationHelper.showLoading(
      context: context,
      message: translationService.translate(SyncTranslationKeys.syncInProgress),
      duration: const Duration(seconds: 30),
    );

    SyncNowCommandResponse? response;
    try {
      response = await mediator.send<SyncNowCommand, SyncNowCommandResponse>(SyncNowCommand());
    } catch (error) {
      Logger.error('Manual sync failed: ${error.runtimeType}');
    }
    if (!mounted) return;

    OverlayNotificationHelper.hideNotification();
    final succeeded = response != null && !response.hasErrors && response.isComplete;
    if (response != null) _recordPeerResults(response);
    _showSyncStatus(SyncStatus(state: succeeded ? SyncState.completed : SyncState.error, isManual: true));
    _showOutcome(succeeded);
    if (succeeded) await onRefresh();
  }

  void _recordPeerResults(SyncNowCommandResponse response) {
    for (final peer in response.report.peers) {
      final isComplete = peer.category == null && (peer.result?.isComplete ?? false);
      _lastSyncResultByDeviceId[peer.memberId] = isComplete ? SyncState.completed : SyncState.error;
    }
  }

  void _showSyncStatus(SyncStatus status) {
    setState(() => currentSyncStatus = status);
    if (status.isSyncing) {
      if (!syncButtonAnimationController.isAnimating) syncButtonAnimationController.repeat();
      return;
    }
    syncButtonAnimationController.stop();
    syncButtonAnimationController.reset();
  }

  void _showOutcome(bool succeeded) {
    if (succeeded) {
      SyncErrorHandler.showSyncSuccess(
        context: context,
        translationService: translationService,
        messageKey: SyncTranslationKeys.syncCompleted,
      );
      return;
    }
    SyncErrorHandler.showSyncError(
      context: context,
      translationService: translationService,
      errorKey: SyncTranslationKeys.syncDevicesError,
    );
  }
}
