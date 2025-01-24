import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';

class NavigationItems {
  static List<NavItem> topNavItems = [
    NavItem(title: 'Today', icon: Icons.today, route: TodayPage.route),
    NavItem(title: 'Tasks', icon: Icons.check_circle, route: TasksPage.route),
    NavItem(title: 'Habits', icon: Icons.refresh, route: HabitsPage.route),
    NavItem(title: 'App Usages', icon: Icons.bar_chart, route: AppUsageViewPage.route),
    NavItem(title: 'Tags', icon: Icons.label, route: TagsPage.route),
  ];

  static List<NavItem> bottomNavItems = [
    NavItem(title: 'Settings', icon: Icons.settings, route: SettingsPage.route),
    NavItem(
        title: 'Buy me a coffee',
        icon: Icons.coffee,
        onTap: (context) async {
          Navigator.of(context).pop(); // Close drawer if open
          await launchUrl(Uri.parse(AppInfo.supportUrl), mode: LaunchMode.externalApplication);
        }),
  ];
}
