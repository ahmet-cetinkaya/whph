import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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
    try {
      final setting = await _settingRepository.getByKey(Settings.notifications);
      if (setting == null) {
        // Create default setting if not exists
        await _settingRepository.add(Setting(
          id: nanoid(),
          key: Settings.notifications,
          value: 'true',
          valueType: SettingValueType.bool,
          createdDate: DateTime.now(),
        ));
        _isEnabled = true;
      } else {
        _isEnabled = setting.value == 'true';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ERROR: Error loading notification setting: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      await _notificationService.setEnabled(value);
      await _loadNotificationSetting();
    } catch (e) {
      debugPrint('Error toggling notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_translationService.translate(value
                  ? SettingsTranslationKeys.enableNotificationsError
                  : SettingsTranslationKeys.disableNotificationsError))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
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
