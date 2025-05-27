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

class App extends StatefulWidget {
  const App({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _mediator = container.resolve<Mediator>();
  final _supportDialogService = container.resolve<ISupportDialogService>();
  final _setupService = container.resolve<ISetupService>();
  bool _isCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkAndShowOnboarding();
    _checkAndShowSupportDialog();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (!_isCheckedUpdate) {
      await _setupService.checkForUpdates(context);
      setState(() {
        _isCheckedUpdate = true;
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
            size: DialogSize.min,
            isDismissible: false,
            child: const OnboardingDialog(),
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
