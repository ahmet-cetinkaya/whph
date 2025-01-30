import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/api/api.dart';
import 'package:whph/application/application_container.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/dependency_injection/container.dart' as acore;
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/persistence/persistence_container.dart';
import 'package:whph/presentation/app.dart';
import 'package:whph/presentation/presentation_container.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:window_manager/window_manager.dart';
import 'main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/shared/constants/app_args.dart';

late final IContainer container;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  container = acore.Container();
  initializeJsonMapper();
  registerPersistence(container);
  registerInfrastructure(container);
  registerApplication(container);
  registerPresentation(container);

  // Initialize services
  final translationService = container.resolve<ITranslationService>();
  await translationService.init();

  final notificationService = container.resolve<INotificationService>();
  await notificationService.init();

  await runDesktopWorkers();

  await runBackgroundWorkers();

  runApp(
    translationService.wrapWithTranslations(const App()),
  );
}

Future<void> runDesktopWorkers() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  // Initialize setup service for desktop platforms
  final setupService = container.resolve<ISetupService>();
  await setupService.setupEnvironment();

  // Update window manager settings
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  if (!kDebugMode) await windowManager.setMinimumSize(const Size(800, 600));

  // Initialize system tray service
  final systemTrayService = container.resolve<ISystemTrayService>();
  await systemTrayService.init();

  // Ensure startup settings are synced
  final startupService = container.resolve<IStartupSettingsService>();
  await startupService.ensureStartupSettingSync();

  // Check if app should start minimized
  if (Platform.environment.containsKey('FLUTTER_TEST') == false) {
    final args = Platform.executableArguments;
    if (args.contains(AppArgs.systemTray)) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  // Start WebSocket server
  startWebSocketServer();
}

Future<void> runBackgroundWorkers() async {
  final mediator = container.resolve<Mediator>();

  if (Platform.isAndroid || Platform.isIOS) {
    // Start sync and app usage tracking for mobile platforms
    mediator.send(StartSyncCommand());
  }

  // Start app usage tracking for all platforms
  await mediator.send(StartTrackAppUsagesCommand());
}
