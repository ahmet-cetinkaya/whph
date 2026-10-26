import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_lan_sync_adapter.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Mixin for the desktop sync mode in the sync devices page: server mode makes
/// the LAN server listen, client mode keeps the port closed (PB-6).
mixin DesktopSyncModeMixin<T extends StatefulWidget> on State<T> {
  static const String desktopSyncModeSettingKey = 'desktop_sync_mode';

  // Services to be provided by the implementing class
  Mediator get mediator;
  ITranslationService get translationService;
  ISettingRepository get settingRepository;
  DesktopLanSyncAdapter? get desktopLanSyncAdapter;

  // State - to be managed by implementing class
  DesktopSyncMode _desktopSyncMode = DesktopSyncMode.server;
  DesktopSyncMode get desktopSyncMode => _desktopSyncMode;
  set desktopSyncMode(DesktopSyncMode value) => _desktopSyncMode = value;

  // Server mode state accessor (to be provided by implementing class or ServerModeMixin)
  bool get isServerMode;
  set isServerMode(bool value);

  /// Load desktop sync mode preference from settings and apply it.
  Future<void> loadDesktopSyncModePreference() async {
    final adapter = desktopLanSyncAdapter;
    if (!PlatformUtils.isDesktop || adapter == null) return;

    try {
      final modeSetting = await settingRepository.getByKey(desktopSyncModeSettingKey);
      final mode = DesktopSyncMode.values.firstWhere(
        (candidate) => candidate.name == modeSetting?.value,
        orElse: () => DesktopSyncMode.server,
      );

      await adapter.applyMode(mode);
      _showMode(mode);
    } catch (e) {
      Logger.error('Failed to load desktop sync mode preference: $e');
    }
  }

  /// Toggle desktop sync mode between server (default) and client mode
  Future<void> toggleDesktopSyncMode() async {
    final adapter = desktopLanSyncAdapter;
    if (!PlatformUtils.isDesktop || adapter == null) return;

    final targetMode =
        _desktopSyncMode == DesktopSyncMode.client ? DesktopSyncMode.server : DesktopSyncMode.client;
    try {
      await adapter.applyMode(targetMode);
      await saveDesktopSyncModePreference(targetMode);
      _showMode(targetMode);

      if (!mounted) return;
      OverlayNotificationHelper.showSuccess(
        context: context,
        message: translationService.translate(targetMode == DesktopSyncMode.client
            ? SyncTranslationKeys.desktopClientModeStarted
            : SyncTranslationKeys.desktopClientModeStopped),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Logger.error('Error toggling desktop sync mode: $e');
      if (!mounted) return;
      OverlayNotificationHelper.showError(
        context: context,
        message: translationService.translate(SyncTranslationKeys.desktopSyncModeToggleError),
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _showMode(DesktopSyncMode mode) {
    if (!mounted) return;
    setState(() {
      _desktopSyncMode = mode;
      isServerMode = mode == DesktopSyncMode.server;
    });
  }

  /// Save desktop sync mode preference to settings
  Future<void> saveDesktopSyncModePreference(DesktopSyncMode mode) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await mediator.send(SaveSettingCommand(
        key: desktopSyncModeSettingKey,
        value: mode.name,
        valueType: SettingValueType.string,
      ));
    } catch (e) {
      Logger.error('Failed to save desktop sync mode preference: $e');
    }
  }
}
