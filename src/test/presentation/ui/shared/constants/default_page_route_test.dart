import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/shared/constants/app_routes.dart';

/// Builds what `pageForRoute` produces. The page widgets resolve services from
/// the DI container, so the builder is invoked directly rather than mounted.
Widget resolvePage(String? routeName) {
  final resolved = AppRoutes.pageForRoute(routeName);
  if (resolved is! Builder) return resolved;

  return resolved.builder(_StubContext());
}

void main() {
  group('the page the app starts on', () {
    test('is the stored page', () {
      expect(resolvePage(TasksPage.route), isA<TasksPage>());
      expect(resolvePage(HabitsPage.route), isA<HabitsPage>());
      expect(resolvePage(NotesPage.route), isA<NotesPage>());
    });

    test('is Today when nothing is stored', () {
      expect(resolvePage(null), isA<TodayPage>());
    });

    test('is Today when the stored page no longer exists', () {
      expect(resolvePage('/a-page-that-was-removed'), isA<TodayPage>());
    });
  });
}

class _StubContext extends Fake implements BuildContext {}
