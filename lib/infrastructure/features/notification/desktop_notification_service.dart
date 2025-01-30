import 'package:local_notifier/local_notifier.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';

class DesktopNotificationService implements INotificationService {
  final ISettingRepository _settingRepository;
  final List<LocalNotification> _activeDesktopNotifications = [];

  DesktopNotificationService(this._settingRepository);

  @override
  Future<void> init() async {
    await localNotifier.setup(appName: AppInfo.name);
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await isEnabled()) return;

    final notification = LocalNotification(
      title: title,
      body: body,
      identifier: payload,
      actions: payload != null ? [LocalNotificationAction(type: 'button', text: 'Open')] : null,
    );

    await notification.show();
    _activeDesktopNotifications.add(notification);
  }

  @override
  Future<void> clearAll() async {
    for (final notification in _activeDesktopNotifications) {
      await notification.close();
    }
    _activeDesktopNotifications.clear();
  }

  @override
  Future<void> destroy() async {
    await clearAll();
    _activeDesktopNotifications.clear();
  }

  @override
  Future<bool> isEnabled() async {
    final setting = await _settingRepository.getByKey(Settings.notifications);
    return setting?.value == 'false' ? false : true; // Default to true if no setting
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final setting = await _settingRepository.getByKey(Settings.notifications);
    if (setting != null) {
      setting.value = enabled.toString();
      await _settingRepository.update(setting);
    } else {
      await _settingRepository.add(Setting(
        id: nanoid(),
        key: Settings.notifications,
        value: enabled.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTime.now(),
      ));
    }
  }
}
