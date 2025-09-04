import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/app/services/app_initialization_service.dart';
import 'package:whph/presentation/ui/app/services/app_lifecycle_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_routes.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    required this.navigatorKey,
    required this.container,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final IContainer container;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppInitializationService _initializationService;
  late final AppLifecycleService _lifecycleService;
  late final IThemeService _themeService;

  @override
  void initState() {
    super.initState();

    // Initialize services with dependencies from container
    _initializationService = AppInitializationService(
      widget.container.resolve<Mediator>(),
      widget.container.resolve<ISupportDialogService>(),
      widget.container.resolve<ISetupService>(),
    );

    _lifecycleService = AppLifecycleService(
      widget.container.resolve<ISystemTrayService>(),
    );

    _themeService = widget.container.resolve<IThemeService>();

    _lifecycleService.initialize();
    _initializeApp();
  }

  @override
  void dispose() {
    _lifecycleService.dispose();
    super.dispose();
  }

  /// Initialize app-level services and dialogs
  Future<void> _initializeApp() async {
    await _initializationService.initializeApp(widget.navigatorKey);

    // Save current locale for background notifications
    await _saveCurrentLocaleForNotifications();
  }

  /// Save the current locale to ensure notifications work in background
  Future<void> _saveCurrentLocaleForNotifications() async {
    try {
      final currentLocale = context.locale.languageCode;
      await BackgroundTranslationService().saveCurrentLocale(currentLocale);
    } catch (e) {
      // Error handled silently to not block app initialization
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        return MaterialApp(
          navigatorKey: widget.navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: AppInfo.name,
          theme: _themeService.themeData,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: AppRoutes.defaultRoute,
        );
      },
    );
  }
}
