import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/infrastructure/features/notification/notification_service.dart';
import 'package:whph/presentation/features/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/features/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/infrastructure/features/system_tray/system_tray_service.dart';

void registerInfrastructure(IContainer container) {
  container.registerSingleton<ISystemTrayService>((_) => SystemTrayService());
  container.registerSingleton<INotificationService>((_) => NotificationService());
}
