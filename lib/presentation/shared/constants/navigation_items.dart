import 'package:flutter/material.dart';
import 'package:whph/presentation/features/about/components/support_dialog.dart';
import 'package:whph/presentation/features/about/constants/about_translation_keys.dart';
import '../constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';

class NavigationItems {
  static List<NavItem> topNavItems = [
    NavItem(titleKey: SharedTranslationKeys.navToday, icon: Icons.today, route: TodayPage.route),
    NavItem(titleKey: SharedTranslationKeys.navTasks, icon: Icons.check_circle, route: TasksPage.route),
    NavItem(titleKey: SharedTranslationKeys.navHabits, icon: Icons.refresh, route: HabitsPage.route),
    NavItem(titleKey: SharedTranslationKeys.navNotes, icon: Icons.note_alt_outlined, route: NotesPage.route),
    NavItem(titleKey: SharedTranslationKeys.navAppUsages, icon: Icons.bar_chart, route: AppUsageViewPage.route),
    NavItem(titleKey: SharedTranslationKeys.navTags, icon: Icons.label, route: TagsPage.route),
  ];

  static List<NavItem> bottomNavItems = [
    NavItem(titleKey: SharedTranslationKeys.navSettings, icon: Icons.settings, route: SettingsPage.route),
    NavItem(
        titleKey: AboutTranslationKeys.supportMeButtonText,
        icon: Icons.coffee,
        onTap: (context) {
          showDialog(
            context: context,
            builder: (context) => SupportDialog(),
          );
        }),
  ];
}
