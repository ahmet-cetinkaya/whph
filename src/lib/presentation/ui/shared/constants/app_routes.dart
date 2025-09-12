import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/ui/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/ui/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page.dart';
import 'package:whph/presentation/ui/features/tags/pages/tag_details_page.dart';

class AppRoutes {
  static final defaultRouteName = TodayPage.route;
  static final defaultRoute = TodayPage();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    final arguments = settings.arguments as Map<String, dynamic>?;

    switch (settings.name) {
      case TodayPage.route:
        page = TodayPage();
        break;
      case TasksPage.route:
        page = const TasksPage();
        break;
      case TagsPage.route:
        page = TagsPage();
        break;
      case HabitsPage.route:
        page = HabitsPage();
        break;
      case NotesPage.route:
        page = const NotesPage();
        break;
      case AppUsageViewPage.route:
        page = AppUsageViewPage();
        break;
      case SyncDevicesPage.route:
        page = SyncDevicesPage();
        break;
      case MarathonPage.route:
        page = const MarathonPage();
        break;
      case AppUsageDetailsPage.route:
        if (arguments == null || arguments['id'] == null) {
          page = TodayPage();
        } else {
          page = AppUsageDetailsPage(appUsageId: arguments['id'] as String);
        }
        break;
      case TaskDetailsPage.route:
        if (arguments?['id'] == null) {
          page = TodayPage();
        } else {
          page = TaskDetailsPage(taskId: arguments!['id'] as String);
        }
        break;
      case HabitDetailsPage.route:
        if (arguments?['id'] == null) {
          page = TodayPage();
        } else {
          page = HabitDetailsPage(habitId: arguments!['id'] as String);
        }
        break;
      case NoteDetailsPage.route:
        if (arguments?['id'] == null) {
          page = TodayPage();
        } else {
          page = NoteDetailsPage(noteId: arguments!['id'] as String);
        }
        break;
      case QRCodeScannerPage.route:
        page = const QRCodeScannerPage();
        break;
      case AddSyncDevicePage.route:
        page = const AddSyncDevicePage();
        break;
      case TagDetailsPage.route:
        if (arguments?['id'] == null) {
          page = TodayPage();
        } else {
          page = TagDetailsPage(tagId: arguments!['id'] as String);
        }
        break;
      case SettingsPage.route:
        page = const SettingsPage();
        break;
      case AppUsageRulesPage.route:
        page = const AppUsageRulesPage();
        break;
      default:
        page = TodayPage();
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}
