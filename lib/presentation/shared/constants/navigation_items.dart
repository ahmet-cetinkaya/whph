import 'package:flutter/material.dart';
import 'package:whph/presentation/features/about/components/support_dialog.dart';
import 'package:whph/presentation/features/about/constants/about_translation_keys.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
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
    NavItem(titleKey: SharedTranslationKeys.navHabits, icon: HabitUiConstants.habitIcon, route: HabitsPage.route),
    NavItem(titleKey: SharedTranslationKeys.navNotes, icon: Icons.note_alt_outlined, route: NotesPage.route),
    NavItem(titleKey: SharedTranslationKeys.navAppUsages, icon: Icons.bar_chart, route: AppUsageViewPage.route),
    NavItem(titleKey: SharedTranslationKeys.navTags, icon: TagUiConstants.tagIcon, route: TagsPage.route),
  ];

  static List<NavItem> bottomNavItems = [
    NavItem(titleKey: SharedTranslationKeys.navSettings, icon: Icons.settings, route: SettingsPage.route),
    NavItem(
        titleKey: AboutTranslationKeys.supportMeButtonText,
        icon: Icons.coffee,
        onTap: (context) {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: context,
            size: DialogSize.min,
            child: SupportDialog(),
          );
        }),
  ];
}
