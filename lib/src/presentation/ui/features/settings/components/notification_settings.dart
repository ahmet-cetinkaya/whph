import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final _notificationService = container.resolve<INotificationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  final _translationService = container.resolve<ITranslationService>();

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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications),
        title: Text(
          _translationService.translate(SettingsTranslationKeys.notificationsTitle),
          style: AppTheme.bodyMedium,
        ),
        trailing: _isLoading || _isUpdating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: _isEnabled,
                onChanged: _toggleNotifications,
              ),
        onTap: () => _isLoading || _isUpdating ? null : _toggleNotifications(!_isEnabled),
      ),
    );
  }
}
