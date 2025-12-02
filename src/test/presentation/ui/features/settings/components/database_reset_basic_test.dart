import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/features/settings/components/reset_database_dialog.dart';
import 'package:whph/presentation/ui/features/settings/components/restart_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database Reset Basic UI Tests', () {
    testWidgets('ResetDatabaseDialog renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const ResetDatabaseDialog(),
          ),
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
          home: Scaffold(
            body: const RestartScreen(),
          ),
        ),
      );

      // Verify the restart screen renders
      expect(find.byType(RestartScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('ResetDatabaseDialog has required components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const ResetDatabaseDialog(),
          ),
        ),
      );

      // Check for key components
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byType(SwipeToConfirm), findsOneWidget);
    });

    testWidgets('RestartScreen has success indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const RestartScreen(),
          ),
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
            home: Scaffold(
              body: const ResetDatabaseDialog(),
            ),
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
            home: Scaffold(
              body: const RestartScreen(),
            ),
          ),
        );

        // Let the timer run briefly
        await tester.pump(const Duration(seconds: 1));

        // Remove the widget
        await tester.pumpWidget(Container());

        // Should not throw any exceptions (timer disposed properly)
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('widgets are focusable and accessible', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  ResetDatabaseDialog(),
                  RestartScreen(),
                ],
              ),
            ),
          ),
        );

        // Test keyboard navigation
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        // Should remain stable
        expect(find.byType(ResetDatabaseDialog), findsOneWidget);
        expect(find.byType(RestartScreen), findsOneWidget);
      });
    });
  });
}
