import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/presentation/shared/constants/setting_keys.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/about/components/onboarding_dialog.dart';
import 'package:whph/presentation/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/app_routes.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'dart:io';

class App extends StatefulWidget {
  const App({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _mediator = container.resolve<Mediator>();
  final _supportDialogService = container.resolve<ISupportDialogService>();
  final _setupService = container.resolve<ISetupService>();
  final _systemTrayService = container.resolve<ISystemTrayService>();
  bool _isCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndShowOnboarding();
    _checkAndShowSupportDialog();
    _checkForUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up persistent notifications when app is terminated
    if (Platform.isAndroid || Platform.isIOS) {
      _systemTrayService.destroy().catchError((error) {
        debugPrint('Error cleaning up system tray on dispose: $error');
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Clean up persistent notifications when app goes to background on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        // Clear persistent notifications when app is backgrounded or closed
        _systemTrayService.destroy().catchError((error) {
          // Handle errors gracefully - notification cleanup is not critical
          debugPrint('Error cleaning up system tray: $error');
        });
      } else if (state == AppLifecycleState.resumed) {
        // Reinitialize system tray when app is resumed to ensure proper functionality
        _systemTrayService.init().catchError((error) {
          debugPrint('Error reinitializing system tray: $error');
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (!_isCheckedUpdate) {
      // Add a delay to ensure app is fully loaded, similar to other dialog services
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (mounted && widget.navigatorKey.currentContext != null) {
          await _setupService.checkForUpdates(widget.navigatorKey.currentContext!);
          if (mounted) {
            setState(() {
              _isCheckedUpdate = true;
            });
          }
        }
      });
    }
  }

  Future<void> _checkAndShowSupportDialog() async {
    // Add a small delay to ensure app is fully loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && widget.navigatorKey.currentContext != null) {
        _supportDialogService.checkAndShowSupportDialog(widget.navigatorKey.currentContext!);
      }
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    GetSettingQueryResponse? setting;

    try {
      setting = await _mediator
          .send<GetSettingQuery, GetSettingQueryResponse>(GetSettingQuery(key: SettingKeys.onboardingCompleted));
    } catch (e) {
      debugPrint('Error fetching onboarding status: $e');
    }

    final hasCompletedOnboarding = setting?.value == 'true';
    if (!hasCompletedOnboarding) {
      // Add a small delay to ensure the app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.navigatorKey.currentContext != null) {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: widget.navigatorKey.currentContext!,
            child: const OnboardingDialog(),
            isDismissible: false,
            size: DialogSize.min,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: AppInfo.name,
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: AppRoutes.defaultRoute,
    );
  }
}
