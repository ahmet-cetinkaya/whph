import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';

import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      NavItem('Tasks', TasksPage.route),
      NavItem('Tags', TagsPage.route),
      NavItem('Habits', HabitsPage.route),
      NavItem('App Usages', AppUsageViewPage.route),
      NavItem('Sync Devices', SyncDevicesPage.route),
    ];

    final routes = {
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
      home: ResponsiveScaffoldLayout(appBarTitle: const Text('WHPH'), navItems: navItems, routes: routes),
    );
  }
}
