import 'package:flutter/material.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';

class NotificationSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const NotificationSettings({super.key, this.onLoaded});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final _notificationService = container.resolve<INotificationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: "Error loading notification settings",
      operation: () async {
        final setting = await _settingRepository.getByKey(SettingKeys.notifications);
        if (setting == null) {
          // Create default setting if not exists
          await _settingRepository.add(Setting(
            id: KeyHelper.generateStringId(),
            key: SettingKeys.notifications,
            value: 'true',
            valueType: SettingValueType.bool,
            createdDate: DateTime.now().toUtc(),
          ));
          _isEnabled = true;
        } else {
          _isEnabled = setting.value == 'true';
        }
        return true;
      },
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
      onError: (e) {
        DomainLogger.error('Error loading notification settings: $e');
        widget.onLoaded?.call();
      },
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_isUpdating) return;

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isUpdating = isLoading;
      }),
      errorMessage: _translationService.translate(
          value ? SettingsTranslationKeys.enableNotificationsError : SettingsTranslationKeys.disableNotificationsError),
      operation: () async {
        await _notificationService.setEnabled(value);
        return true;
      },
      onSuccess: (_) async {
        await _loadNotificationSetting();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return SettingsMenuTile(
          icon: Icons.notifications,
          title: _translationService.translate(SettingsTranslationKeys.notificationsTitle),
          trailing: _isLoading || _isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: theme.colorScheme.primary,
                ),
          onTap: () => _isLoading || _isUpdating ? null : _toggleNotifications(!_isEnabled),
          isActive: true,
        );
      },
    );
  }
}
