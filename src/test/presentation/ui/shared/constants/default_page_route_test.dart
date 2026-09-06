import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/shared/constants/app_routes.dart';

Widget pageOf(Route<dynamic> route) {
  return (route as PageRouteBuilder).pageBuilder(_StubContext(), kAlwaysCompleteAnimation, kAlwaysCompleteAnimation);
}

void main() {
  group('the page the app starts on', () {
    test('is the stored page', () {
      expect(pageOf(AppRoutes.buildInitialRoutes(TasksPage.route).single), isA<TasksPage>());
      expect(pageOf(AppRoutes.buildInitialRoutes(HabitsPage.route).single), isA<HabitsPage>());
      expect(pageOf(AppRoutes.buildInitialRoutes(NotesPage.route).single), isA<NotesPage>());
    });

    test('is Today when nothing is stored', () {
      expect(pageOf(AppRoutes.buildInitialRoutes(null).single), isA<TodayPage>());
    });

    test('is Today when the stored page no longer exists', () {
      expect(pageOf(AppRoutes.buildInitialRoutes('/a-page-that-was-removed').single), isA<TodayPage>());
    });

    test('is the only page, so Back has nothing to fall onto', () {
      expect(AppRoutes.buildInitialRoutes(TasksPage.route), hasLength(1));
      expect(AppRoutes.buildInitialRoutes(null), hasLength(1));
    });

    test('carries its route name so the navigation bar can highlight it', () {
      // Without a name the bar cannot tell which page is open and falls back to
      // highlighting Today, whichever page the user actually landed on.
      expect(AppRoutes.buildInitialRoutes(TasksPage.route).single.settings.name, TasksPage.route);
      expect(AppRoutes.buildInitialRoutes(HabitsPage.route).single.settings.name, HabitsPage.route);
      expect(AppRoutes.buildInitialRoutes(null).single.settings.name, AppRoutes.defaultRouteName);
    });
  });
}

class _StubContext extends Fake implements BuildContext {}
