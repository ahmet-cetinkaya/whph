import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:infrastructure_android/features/sync/android_server_sync_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Mixin for handling Android server mode functionality in sync devices page.
mixin ServerModeMixin<T extends StatefulWidget> on State<T> {
  static const String serverModeSettingKey = 'sync_server_mode_enabled';

  // Services to be provided by the implementing class
  Mediator get mediator;
  ITranslationService get translationService;
  ISettingRepository get settingRepository;
  AndroidServerSyncService? get serverSyncService;

  // State
  bool _isServerMode = false;
  bool get isServerMode => _isServerMode;
  set isServerMode(bool value) => _isServerMode = value;

  /// Load server mode preference and sync UI state
  Future<void> loadServerModePreference() async {
    if (!Platform.isAndroid || serverSyncService == null) return;

    try {
      // Check if server is already running (started by platform initialization)
      final isServerRunning = serverSyncService!.isServerMode;
      DomainLogger.info('Android server mode check: isServerRunning=$isServerRunning');

      if (isServerRunning && mounted) {
        setState(() {
          _isServerMode = true;
        });
        DomainLogger.info('Server mode already running from platform initialization - UI updated to server mode');
      } else {
        // Fallback: check preference and start if needed
        final setting = await settingRepository.getByKey(serverModeSettingKey);
        final shouldStartServer = setting?.getValue<bool>() ?? false;
        DomainLogger.info('Server mode preference check: shouldStartServer=$shouldStartServer');

        if (shouldStartServer) {
          DomainLogger.info('Auto-starting server mode from saved preference');
          await startServerModeFromPreference();
        }
      }
    } catch (e) {
      DomainLogger.error('Failed to load server mode preference: $e');
    }
  }

  /// Start server mode without UI notifications (for auto-start)
  Future<void> startServerModeFromPreference() async {
    if (serverSyncService == null) return;

    try {
      final success = await serverSyncService!.startAsServer();

      if (success && mounted) {
        setState(() {
          _isServerMode = true;
        });
        DomainLogger.info('Server mode auto-started successfully');
      } else {
        DomainLogger.warning('Failed to auto-start server mode');
      }
    } catch (e) {
      DomainLogger.error('Error auto-starting server mode: $e');
    }
  }

  /// Toggle server mode on/off
  Future<void> toggleServerMode() async {
    if (!Platform.isAndroid || serverSyncService == null) return;

    try {
      if (_isServerMode) {
        // Stop server mode
        DomainLogger.info('Stopping mobile sync server mode...');
        await serverSyncService!.stopServer();

        // Save preference: server mode disabled
        await saveServerModePreference(false);

        setState(() {
          _isServerMode = false;
        });

        if (mounted) {
          OverlayNotificationHelper.showInfo(
            context: context,
            message: translationService.translate(SyncTranslationKeys.serverModeStopped),
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Start server mode
        DomainLogger.info('Starting mobile sync server mode...');

        if (mounted) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: translationService.translate(SyncTranslationKeys.serverModeStarting),
            duration: const Duration(seconds: 10),
          );
        }

        final success = await serverSyncService!.startAsServer();

        if (mounted) {
          OverlayNotificationHelper.hideNotification();

          if (success) {
            // Save preference: server mode enabled
            await saveServerModePreference(true);

            setState(() {
              _isServerMode = true;
            });

            if (mounted) {
              OverlayNotificationHelper.showSuccess(
                context: context,
                message: translationService.translate(SyncTranslationKeys.serverModeActive),
                duration: const Duration(seconds: 4),
              );
            }
          } else {
            OverlayNotificationHelper.showError(
              context: context,
              message: translationService.translate(SyncTranslationKeys.serverModeStartFailed),
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      DomainLogger.error('Error toggling server mode: $e');
      if (mounted) {
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showError(
          context: context,
          message: '${translationService.translate(SyncTranslationKeys.serverModeError)}: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Save server mode preference to settings
  Future<void> saveServerModePreference(bool enabled) async {
    try {
      final command = SaveSettingCommand(
        key: serverModeSettingKey,
        value: enabled.toString(),
        valueType: SettingValueType.bool,
      );

      await mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(command);
      DomainLogger.debug('Server mode preference saved: $enabled');
    } catch (e) {
      DomainLogger.error('Failed to save server mode preference: $e');
    }
  }
}
