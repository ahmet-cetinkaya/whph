import 'dart:io';

import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/infrastructure/features/notification/notification_service.dart';
import 'package:whph/infrastructure/features/system_tray/mobile_system_tray_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/infrastructure/features/system_tray/system_tray_service.dart';
import 'package:whph/infrastructure/features/notification/mobile_notification_service.dart';

void registerInfrastructure(IContainer container) {
  container.registerSingleton<ISystemTrayService>(
      (_) => (Platform.isAndroid || Platform.isIOS) ? MobileSystemTrayService() : SystemTrayService());

  container.registerSingleton<INotificationService>(
      (_) => (Platform.isAndroid || Platform.isIOS) ? MobileNotificationService() : NotificationService());
}
