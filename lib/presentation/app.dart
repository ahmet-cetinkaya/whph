import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/about/components/onboarding_dialog.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/app_routes.dart';

class App extends StatefulWidget {
  const App({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _mediator = container.resolve<Mediator>();

  @override
  void initState() {
    super.initState();
    _checkAndShowOnboarding();
  }

  Future<void> _checkAndShowOnboarding() async {
    GetSettingQueryResponse? setting;

    try {
      setting = await _mediator
          .send<GetSettingQuery, GetSettingQueryResponse>(GetSettingQuery(key: Settings.onboardingCompleted));
    } catch (e) {
      debugPrint('Error fetching onboarding status: $e');
    }

    final hasCompletedOnboarding = setting?.value == 'true';
    if (!hasCompletedOnboarding) {
      // Add a small delay to ensure the app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.navigatorKey.currentContext != null) {
          showDialog(
            context: widget.navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => const OnboardingDialog(),
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
