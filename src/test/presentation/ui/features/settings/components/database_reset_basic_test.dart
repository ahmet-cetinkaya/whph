import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/features/settings/components/reset_database_dialog.dart';
import 'package:whph/presentation/ui/features/settings/components/restart_screen.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize container for tests
  setUpAll(() {
    try {
      container = FakeContainer();
    } catch (_) {
      // Container might be already initialized in some test environments
    }

    // Register the service if the container is our fake
    if (container is FakeContainer) {
      (container as FakeContainer).register<ITranslationService>(FakeTranslationService());
    }
  });

  group('Database Reset Basic UI Tests', () {
    testWidgets('ResetDatabaseDialog renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ResetDatabaseDialog(),
        ),
      );

      // Verify the dialog renders
      expect(find.byType(ResetDatabaseDialog), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('RestartScreen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const RestartScreen(),
        ),
      );

      // Verify the restart screen renders
      expect(find.byType(RestartScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('ResetDatabaseDialog has required components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ResetDatabaseDialog(),
        ),
      );

      // Check for key components
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byType(SwipeToConfirm), findsOneWidget);
    });

    testWidgets('RestartScreen has success indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const RestartScreen(),
        ),
      );

      // Check for success indicators
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    group('Widget Lifecycle Tests', () {
      testWidgets('ResetDatabaseDialog handles disposal correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const ResetDatabaseDialog(),
          ),
        );

        // Remove the widget
        await tester.pumpWidget(Container());

        // Should not throw any exceptions
        expect(tester.takeException(), isNull);
      });

      testWidgets('RestartScreen handles timer disposal correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const RestartScreen(),
          ),
        );

        // Let the timer run briefly
        await tester.pump(const Duration(milliseconds: 100));

        // Remove the widget
        await tester.pumpWidget(Container());

        // Should not throw any exceptions
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('ResetDatabaseDialog has proper semantics', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const ResetDatabaseDialog(),
          ),
        );

        // Check for semantic labels
        expect(find.bySemanticsLabel('Reset Database'), findsOneWidget);
      });

      testWidgets('RestartScreen has proper semantics', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const RestartScreen(),
          ),
        );

        // Check for success indicator semantics
        expect(find.bySemanticsLabel(contains('Database Reset Complete')), findsOneWidget);
      });
    });

    group('Platform Integration Tests', () {
      testWidgets('ResetDatabaseDialog handles haptic feedback', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const ResetDatabaseDialog(),
          ),
        );

        // Test haptic feedback
        await tester.tap(find.byType(SwipeToConfirm));
        await tester.pump();

        // Should not throw exceptions
        expect(tester.takeException(), isNull);
      });
    });
  });
}
