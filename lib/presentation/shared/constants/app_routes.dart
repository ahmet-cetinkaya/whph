import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/presentation/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/shared/routes/fade_page_route.dart';

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

    final isNoAnimation = arguments?['noAnimation'] == true;

    if (isNoAnimation) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    final bool useFadeTransition = arguments?['useFadeTransition'] == true;
    if (useFadeTransition) {
      return FadePageRoute(child: page);
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animation for exiting page
        final secondaryFade = Tween(
          begin: 1.0,
          end: 0.0,
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        ));

        const begin = Offset(0.02, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var offsetAnimation = Tween(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1.0, curve: curve),
        ));

        var fadeAnimation = Tween(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
        ));

        var scaleAnimation = Tween(
          begin: 0.97,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 0.9, curve: Curves.easeOutCirc),
        ));

        return Stack(
          children: [
            FadeTransition(
              opacity: secondaryFade,
              child: Container(color: Theme.of(context).scaffoldBackgroundColor),
            ),
            SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 500),
    );
  }
}
