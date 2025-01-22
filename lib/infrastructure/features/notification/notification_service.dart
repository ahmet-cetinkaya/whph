import 'package:local_notifier/local_notifier.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';

class NotificationService implements INotificationService {
  final List<LocalNotification> _activeDesktopNotifications = [];

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
    for (var notification in _activeDesktopNotifications) {
      await notification.close();
    }
    _activeDesktopNotifications.clear();
  }

  @override
  Future<void> destroy() async {
    await clearAll();
    _activeDesktopNotifications.clear();
  }
}
