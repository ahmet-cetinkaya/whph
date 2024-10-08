import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
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
      NavItem('App Usage', AppUsageViewPage.route),
    ];

    final routes = {
      TasksPage.route: (context) => const TasksPage(),
      TagsPage.route: (context) => TagsPage(),
      HabitsPage.route: (context) => HabitsPage(),
      AppUsageViewPage.route: (context) => AppUsageViewPage(),
    };

    return MaterialApp(
      title: 'WHPH',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: ResponsiveScaffoldLayout(title: const Text('WHPH'), navItems: navItems, routes: routes),
    );
  }
}
