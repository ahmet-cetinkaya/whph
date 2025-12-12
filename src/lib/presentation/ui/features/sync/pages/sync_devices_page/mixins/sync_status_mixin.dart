import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Mixin for handling sync status listening and processing in sync devices page.
mixin SyncStatusMixin<T extends StatefulWidget> on State<T> {
  // Services to be provided by the implementing class
  ISyncService get syncService;
  ITranslationService get translationService;
  AndroidServerSyncService? get serverSyncService;

  // State accessors to be provided by implementing class
  bool get isServerMode;
  AnimationController get syncIconAnimationController;
  AnimationController get syncButtonAnimationController;
  SyncStatus get currentSyncStatus;
  set currentSyncStatus(SyncStatus value);

  // Callback for refreshing device list
  Future<void> Function() get onRefresh;

  // Internal state
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  StreamSubscription<dynamic>? _serverSyncEventSubscription;
  Timer? _syncStatusDebounceTimer;
  Timer? _serverSyncTimeoutTimer;
  SyncState? _lastProcessedState;
  DateTime? _lastSyncActivityTime;
  bool _isServerSyncActive = false;

  bool get isServerSyncActive => _isServerSyncActive;

  /// Initialize sync status listeners
  void setupSyncStatusListeners() {
    _setupSyncStatusListener();
    _setupServerSyncStatusListener();
  }

  /// Dispose sync status resources
  void disposeSyncStatusResources() {
    _syncStatusSubscription?.cancel();
    _serverSyncEventSubscription?.cancel();
    _syncStatusDebounceTimer?.cancel();
    _serverSyncTimeoutTimer?.cancel();
  }

  void _setupSyncStatusListener() {
    Logger.debug('Setting up sync status listener for ${isServerMode ? "server" : "client"} mode');

    _syncStatusSubscription = syncService.syncStatusStream.listen((status) {
      if (mounted) {
        currentSyncStatus = status;
        Logger.info(
            'Sync status received: ${status.state} (manual: ${status.isManual}) - serverMode: $isServerMode, syncActive: $_isServerSyncActive');

        // Update last sync activity time ONLY for actual sync events in server mode
        if (isServerMode && status.state == SyncState.syncing) {
          _lastSyncActivityTime = DateTime.now();
          Logger.info('Server sync event (${status.state}) - resetting inactivity timer');
        } else if (isServerMode && status.state == SyncState.idle) {
          Logger.info('Server idle event received - sync activity ended');
        }

        if (isServerMode) {
          Logger.info('Processing in SERVER MODE - calling debounce handler');
          _handleServerModeSyncStatusWithDebounce(status);
        } else {
          Logger.info('Processing in CLIENT MODE - updating UI directly');
          // For client mode, always update UI for any sync status change
          setState(() {});
          _handleSyncStatusChange(status);
        }
      } else {
        Logger.warning('Sync status received but widget not mounted - ignoring');
      }
    });

    // Setup server sync monitoring for Android
    if (Platform.isAndroid && serverSyncService != null) {
      _setupServerSyncMonitoring();
    }

    Logger.debug('Sync status listener setup completed');
  }

  void _setupServerSyncStatusListener() {
    if (!Platform.isAndroid || serverSyncService == null) return;

    Logger.info('Setting up additional Android server sync status listener');

    // Listen to server sync service's own sync status stream if it's different from main service
    if (serverSyncService != syncService) {
      Logger.info('Server sync service is different from main sync service - setting up additional listener');

      _serverSyncEventSubscription = serverSyncService!.syncStatusStream.listen((status) {
        if (mounted) {
          Logger.info(
              'Server sync status received from AndroidServerSyncService: ${status.state} (manual: ${status.isManual})');

          // Forward to main sync service to ensure UI gets updated
          syncService.updateSyncStatus(status);
        }
      });
    } else {
      Logger.info('Server sync service is same as main sync service - no additional listener needed');
    }
  }

  void _handleServerModeSyncStatusWithDebounce(SyncStatus status) {
    // Cancel any existing debounce timer
    _syncStatusDebounceTimer?.cancel();

    Logger.info(
        'Server mode sync status update: ${status.state} (manual: ${status.isManual}, serverMode: $isServerMode, active: $_isServerSyncActive)');

    // Handle syncing state immediately - this is the critical path for starting animation
    if (status.state == SyncState.syncing) {
      Logger.info('SYNCING state detected in server mode');
      if (!_isServerSyncActive) {
        Logger.info('Starting server sync animation - was not active before');
        _isServerSyncActive = true;
        syncIconAnimationController.repeat();
        setState(() {});
        Logger.info('Server sync animation started - real sync activity detected');
      } else {
        Logger.info('Server sync animation already active - continuing');
      }
      // Reset inactivity timer only on actual sync events
      _lastSyncActivityTime = DateTime.now();

      // For syncing state, don't update lastProcessedState yet to allow continuous updates
      // but still debounce to prevent excessive setState calls
      _syncStatusDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted && status.state == SyncState.syncing) {
          _lastProcessedState = status.state;
        }
      });
      return;
    }

    // For non-syncing states, use debouncing to prevent UI flicker
    if (status.state != _lastProcessedState) {
      Logger.info('Non-syncing state (${status.state}) - scheduling debounced processing');
      _syncStatusDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _processServerSyncStatusChange(status);
        }
      });
    } else {
      Logger.info('Same state as last processed (${status.state}) - ignoring');
    }
  }

  void _processServerSyncStatusChange(SyncStatus status) {
    final previousState = _lastProcessedState;
    _lastProcessedState = status.state;

    Logger.info(
        'Processing server sync status change: $previousState → ${status.state} (serverMode: $isServerMode, active: $_isServerSyncActive)');

    switch (status.state) {
      case SyncState.syncing:
        // Already handled immediately in the debounce handler
        break;

      case SyncState.idle:
        if (_isServerSyncActive) {
          _isServerSyncActive = false;
          syncIconAnimationController.stop();
          syncIconAnimationController.reset();
          setState(() {});
          Logger.info('Server sync animation stopped - sync activity ended ($previousState → ${status.state})');
          onRefresh(); // Refresh device list
        }
        break;

      case SyncState.completed:
      case SyncState.error:
        // For server mode, treat completion and error as end of sync
        if (_isServerSyncActive) {
          _isServerSyncActive = false;
          syncIconAnimationController.stop();
          syncIconAnimationController.reset();
          setState(() {});

          if (status.state == SyncState.completed) {
            Logger.info('Server sync completed successfully ($previousState → ${status.state})');
            onRefresh(); // Refresh device list
          } else {
            Logger.info('Server sync error occurred ($previousState → ${status.state})');
          }
        }
        break;
    }
  }

  void _handleSyncStatusChange(SyncStatus status) {
    // Client mode handling - handle ALL sync types for UI consistency
    Logger.debug('Client sync status change: ${status.state} (manual: ${status.isManual})');

    switch (status.state) {
      case SyncState.syncing:
        // Start sync button animation for ANY sync (manual, background, pairing, etc.)
        if (!syncButtonAnimationController.isAnimating) {
          syncButtonAnimationController.repeat();
          Logger.debug('Client sync button animation started (manual: ${status.isManual})');
        }

        // Show overlay notification ONLY for manual syncs in client mode
        if (status.isManual) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: translationService.translate(SyncTranslationKeys.syncInProgress),
            duration: const Duration(seconds: 30),
          );
        }
        break;

      case SyncState.completed:
      case SyncState.error:
      case SyncState.idle:
        // Stop sync button animation for ANY sync completion
        if (syncButtonAnimationController.isAnimating) {
          syncButtonAnimationController.stop();
          syncButtonAnimationController.reset();
          Logger.debug('Client sync button animation stopped (${status.state}, manual: ${status.isManual})');
        }

        if (status.isManual) {
          OverlayNotificationHelper.hideNotification();

          if (status.state == SyncState.completed) {
            SyncErrorHandler.showSyncSuccess(
              context: context,
              translationService: translationService,
              messageKey: SyncTranslationKeys.syncCompleted,
              duration: const Duration(seconds: 3),
            );
          } else if (status.state == SyncState.error) {
            final errorKey = status.errorMessage ?? SyncTranslationKeys.syncDevicesError;

            SyncErrorHandler.showSyncError(
              context: context,
              translationService: translationService,
              errorKey: errorKey,
              errorParams: status.errorParams,
              duration: const Duration(seconds: 5),
            );
          }
        }

        // Refresh device list on ANY sync completion
        if (status.state == SyncState.completed) {
          Future.delayed(const Duration(milliseconds: 100), () {
            onRefresh();
          });
        }
        break;
    }
  }

  void _setupServerSyncMonitoring() {
    if (serverSyncService == null) return;

    Logger.info('Setting up Android server sync monitoring - animation only on real sync activity');

    // Monitor server status and sync activity timeout
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final isServerRunning = serverSyncService!.isServerMode;

        if (isServerRunning && isServerMode) {
          // Server is running - only check for sync activity timeout, don't start animation just because server is ready
          if (_isServerSyncActive && _lastSyncActivityTime != null) {
            final now = DateTime.now();
            const inactivityTimeout = Duration(seconds: 30); // Timeout after sync events

            // Check for full inactivity timeout (30s after last sync activity)
            if (now.difference(_lastSyncActivityTime!) > inactivityTimeout) {
              Logger.info('Server sync timeout - no activity for ${inactivityTimeout.inSeconds}s, stopping animation');
              handleServerSyncStop();
            }
          }
        } else {
          // Server not running or not in server mode - stop animation
          if (_isServerSyncActive) {
            Logger.info('Stopping server sync animation - server not active');
            handleServerSyncStop();
          }
        }
      } catch (e) {
        Logger.debug('Server monitoring error: $e');
      }
    });

    // Don't start animation automatically when server starts - wait for actual sync activity
    Logger.info('Android server sync monitoring active - animation starts only on real sync events');
  }

  /// Handle server sync stop - can be called externally
  void handleServerSyncStop() {
    _isServerSyncActive = false;
    _lastSyncActivityTime = null;

    if (syncIconAnimationController.isAnimating) {
      syncIconAnimationController.stop();
      syncIconAnimationController.reset();
    }

    if (mounted) {
      setState(() {});
    }

    // Cancel timeout timer
    _serverSyncTimeoutTimer?.cancel();
    _serverSyncTimeoutTimer = null;

    // Emit idle status
    syncService.updateSyncStatus(const SyncStatus(state: SyncState.idle, isManual: false));

    Logger.info('Server sync animation stopped - sync activity ended');
  }
}
