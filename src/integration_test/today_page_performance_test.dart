import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph/main.dart' as app;

/// Performance integration test that runs on actual device/emulator.
/// This test measures real render times for TodayPage operations.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final binding = IntegrationTestWidgetsFlutterBinding.instance;

  group('TodayPage Performance Integration Tests', () {
    testWidgets('Measure TodayPage initial load time', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      // Start the app
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      stopwatch.stop();
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 INITIAL APP LOAD: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Navigate to Today page (assuming it's the default or accessible)
      // Wait for the page to be fully rendered
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Measure dialog open performance', (WidgetTester tester) async {
      // Start the app
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Find and tap the floating action button (add task)
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        final stopwatch = Stopwatch()..start();

        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        stopwatch.stop();
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 QUICK ADD DIALOG OPEN: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } else {
        debugPrint('⚠️ FloatingActionButton not found');
      }
    });

    testWidgets('Measure rebuild performance on scroll', (WidgetTester tester) async {
      // Start the app
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Find scrollable area
      final scrollable = find.byType(CustomScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        final stopwatch = Stopwatch()..start();

        // Perform scroll gestures
        await tester.drag(scrollable.first, const Offset(0, -300));
        await tester.pumpAndSettle();

        await tester.drag(scrollable.first, const Offset(0, 300));
        await tester.pumpAndSettle();

        stopwatch.stop();
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 SCROLL UP/DOWN: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } else {
        debugPrint('⚠️ CustomScrollView not found');
      }
    });

    testWidgets('Report frame statistics', (WidgetTester tester) async {
      // Enable frame reporting
      await binding.traceAction(() async {
        app.main([]);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Trigger some UI actions
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab.first);
          await tester.pumpAndSettle();

          // Close dialog
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      }, reportKey: 'today_page_performance');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Frame statistics logged to timeline');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    });
  });
}
