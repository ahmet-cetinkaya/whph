import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:infrastructure_desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Mixin for handling desktop sync mode functionality in sync devices page.
mixin DesktopSyncModeMixin<T extends StatefulWidget> on State<T> {
  static const String desktopSyncModeSettingKey = 'desktop_sync_mode';
  static const String desktopServerAddressSettingKey = 'desktop_server_address';
  static const String desktopServerPortSettingKey = 'desktop_server_port';

  // Services to be provided by the implementing class
  Mediator get mediator;
  ITranslationService get translationService;
  ISettingRepository get settingRepository;
  DesktopSyncService? get desktopSyncService;

  // State - to be managed by implementing class
  DesktopSyncMode _desktopSyncMode = DesktopSyncMode.server;
  DesktopSyncMode get desktopSyncMode => _desktopSyncMode;
  set desktopSyncMode(DesktopSyncMode value) => _desktopSyncMode = value;

  // Server mode state accessor (to be provided by implementing class or ServerModeMixin)
  bool get isServerMode;
  set isServerMode(bool value);

  /// Load desktop sync mode preference from settings
  Future<void> loadDesktopSyncModePreference() async {
    if (!PlatformUtils.isDesktop || desktopSyncService == null) return;

    try {
      // Load sync mode preference
      final syncModeSetting = await settingRepository.getByKey(desktopSyncModeSettingKey);
      if (syncModeSetting != null) {
        final modeValue = syncModeSetting.value;
        final mode = DesktopSyncMode.values.firstWhere(
          (m) => m.name == modeValue,
          orElse: () => DesktopSyncMode.server,
        );

        // Load server connection settings if in client mode
        if (mode == DesktopSyncMode.client) {
          final addressSetting = await settingRepository.getByKey(desktopServerAddressSettingKey);
          final portSetting = await settingRepository.getByKey(desktopServerPortSettingKey);

          if (addressSetting != null && portSetting != null) {
            final address = addressSetting.value;
            final port = int.tryParse(portSetting.value) ?? 44040;

            // Switch to client mode with saved server info
            await desktopSyncService!.switchToClientMode(address, port);
          }
        } else {
          // Switch to server mode
          await desktopSyncService!.switchToMode(mode);
        }

        setState(() {
          _desktopSyncMode = mode;
          isServerMode = mode == DesktopSyncMode.server;
        });
      } else {
        // Default to server mode if no setting exists
        await desktopSyncService!.switchToMode(DesktopSyncMode.server);
        setState(() {
          _desktopSyncMode = DesktopSyncMode.server;
          isServerMode = true;
        });
      }
    } catch (e) {
      DomainLogger.error('Failed to load desktop sync mode preference: $e');
    }
  }

  /// Toggle desktop sync mode between server (default) and client mode
  Future<void> toggleDesktopSyncMode() async {
    if (!PlatformUtils.isDesktop || desktopSyncService == null) return;

    try {
      if (_desktopSyncMode == DesktopSyncMode.client) {
        // Stop client mode - switch back to server mode (default)
        DomainLogger.info('Stopping desktop client mode...');

        await desktopSyncService!.switchToMode(DesktopSyncMode.server);

        // Save server mode preference
        await saveDesktopSyncModePreference(DesktopSyncMode.server);

        setState(() {
          _desktopSyncMode = DesktopSyncMode.server;
          isServerMode = true;
        });

        if (mounted) {
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: translationService.translate(SyncTranslationKeys.desktopClientModeStopped),
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Start client mode - try to connect to saved server or default
        DomainLogger.info('Starting desktop client mode...');

        if (mounted) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: translationService.translate(SyncTranslationKeys.desktopClientModeStarting),
            duration: const Duration(seconds: 5),
          );
        }

        // Load saved server settings - required for client mode
        String? serverAddress;
        int serverPort = 44040;

        try {
          final addressSetting = await settingRepository.getByKey(desktopServerAddressSettingKey);
          final portSetting = await settingRepository.getByKey(desktopServerPortSettingKey);

          if (addressSetting != null && portSetting != null) {
            serverAddress = addressSetting.value;
            serverPort = int.tryParse(portSetting.value) ?? 44040;
          }
        } catch (e) {
          DomainLogger.warning('Could not load saved server settings: $e');
        }

        // If no saved server settings, we still switch to client mode
        // The user can configure the server connection later or via auto-discovery
        if (serverAddress == null || serverAddress.isEmpty) {
          DomainLogger.info('No saved server settings found - proceeding to client mode anyway');
        }

        await desktopSyncService!.switchToMode(DesktopSyncMode.client);

        // Save client mode preference
        await saveDesktopSyncModePreference(DesktopSyncMode.client,
            serverAddress: serverAddress, serverPort: serverPort);

        setState(() {
          _desktopSyncMode = DesktopSyncMode.client;
          isServerMode = false;
        });

        if (mounted) {
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: translationService.translate(SyncTranslationKeys.desktopClientModeStarted),
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      DomainLogger.error('Error toggling desktop sync mode: $e');
      if (mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: translationService.translate(SyncTranslationKeys.desktopSyncModeToggleError),
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Save desktop sync mode preference to settings
  Future<void> saveDesktopSyncModePreference(DesktopSyncMode mode, {String? serverAddress, int? serverPort}) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      // Save sync mode
      await mediator.send(SaveSettingCommand(
        key: desktopSyncModeSettingKey,
        value: mode.name,
        valueType: SettingValueType.string,
      ));

      // Save server connection info if in client mode
      if (mode == DesktopSyncMode.client && serverAddress != null && serverPort != null) {
        await mediator.send(SaveSettingCommand(
          key: desktopServerAddressSettingKey,
          value: serverAddress,
          valueType: SettingValueType.string,
        ));

        await mediator.send(SaveSettingCommand(
          key: desktopServerPortSettingKey,
          value: serverPort.toString(),
          valueType: SettingValueType.int,
        ));
      }
    } catch (e) {
      DomainLogger.error('Failed to save desktop sync mode preference: $e');
    }
  }
}
