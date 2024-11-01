import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/presentation/features/about/components/app_about.dart';
import 'package:whph/domain/features/shared/constants/app_info.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';

import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final topNavItems = [
      NavItem(title: 'Today', icon: Icons.today, route: TodayPage.route),
      NavItem(title: 'Tasks', icon: Icons.check_circle, route: TasksPage.route),
      NavItem(title: 'Tags', icon: Icons.label, route: TagsPage.route),
      NavItem(title: 'Habits', icon: Icons.refresh, route: HabitsPage.route),
      NavItem(title: 'App Usages', icon: Icons.bar_chart, route: AppUsageViewPage.route),
    ];
    final bottomNavItems = [
      NavItem(title: 'Sync Devices', icon: Icons.sync, route: SyncDevicesPage.route),
      NavItem(
          title: 'Buy me a coffee',
          icon: Icons.coffee,
          onTap: (context) {
            launchUrl(Uri.parse(AppInfo.supportUrl), mode: LaunchMode.externalApplication);
          }),
      NavItem(
          title: 'About',
          icon: Icons.info,
          onTap: (context) {
            showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: SingleChildScrollView(child: AppAbout())),
                  );
                });
          }),
    ];

    final routes = {
      TodayPage.route: (context) => TodayPage(),
      TasksPage.route: (context) => const TasksPage(),
      TagsPage.route: (context) => TagsPage(),
      HabitsPage.route: (context) => HabitsPage(),
      AppUsageViewPage.route: (context) => AppUsageViewPage(),
      SyncDevicesPage.route: (context) => SyncDevicesPage(),
    };

    return MaterialApp(
      title: 'WHPH',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: ResponsiveScaffoldLayout(
          appBarTitle: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('lib/domain/features/shared/assets/whph_logo_adaptive_fg.png', width: 32, height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: const Text('WHPH'),
              ),
            ],
          ),
          topNavItems: topNavItems,
          bottomNavItems: bottomNavItems,
          routes: routes,
          defaultRoute: (context) => TodayPage()),
    );
  }
}
