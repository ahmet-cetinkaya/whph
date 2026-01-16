import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph/main.dart' as app;
import 'package:whph/presentation/ui/shared/services/global_error_handler_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';

/// Performance integration test that runs on actual device/emulator.
/// This test measures real render times for TodayPage operations.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final binding = IntegrationTestWidgetsFlutterBinding.instance;

  group('TodayPage Performance Integration Tests', () {
    Future<void> cleanup() async {
      // Release single instance lock so the next main() call can proceed
      try {
        final singleInstanceService = app.container.resolve<ISingleInstanceService>();
        await singleInstanceService.releaseInstance();
      } catch (_) {}

      try {
        app.container.clear();
      } catch (_) {}

      try {
        final db = AppDatabase.instance();
        await db.close();
      } catch (_) {}

      GlobalErrorHandlerService.reset();
      AppDatabase.resetInstance();
      app.navigatorKey = GlobalKey<NavigatorState>();

      // Give a small delay for things to settle
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setUp(() async {
      await cleanup();
    });

    tearDown(() async {
      await cleanup();
    });

    Future<void> startApp(WidgetTester tester) async {
      try {
        // Run main in runAsync to avoid blocking the test zone if it starts long-running tasks
        await tester.runAsync(() async {
          await app.main([]);
        });

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle(
            const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      } catch (e) {
        rethrow;
      }
    }

    testWidgets('Measure TodayPage initial load time', (WidgetTester tester) async {
      try {
        final stopwatch = Stopwatch()..start();

        // Start the app
        await startApp(tester);

        stopwatch.stop();
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 INITIAL APP LOAD: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // Navigate to Today page (assuming it's the default or accessible)
        // Wait for the page to be fully rendered
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsWidgets);
      } finally {
        GlobalErrorHandlerService.reset();
      }
    });

    testWidgets('Measure dialog open performance', (WidgetTester tester) async {
      try {
        // Start the app
        await startApp(tester);

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
      } finally {
        GlobalErrorHandlerService.reset();
      }
    });

    testWidgets('Measure rebuild performance on scroll', (WidgetTester tester) async {
      try {
        // Start the app
        await startApp(tester);

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
      } finally {
        GlobalErrorHandlerService.reset();
      }
    });

    testWidgets('Report frame statistics', (WidgetTester tester) async {
      try {
        // Enable frame reporting
        await binding.traceAction(() async {
          await startApp(tester);

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
      } finally {
        GlobalErrorHandlerService.reset();
      }
    });
  });
}
