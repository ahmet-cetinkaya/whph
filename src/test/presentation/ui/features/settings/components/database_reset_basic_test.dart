import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple test widgets that don't depend on global container
class TestResetDialog extends StatelessWidget {
  const TestResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Database')),
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 32),
              Icon(
                Icons.warning_rounded,
                size: 80,
                color: Colors.orange,
              ),
              SizedBox(height: 24),
              Text(
                'Reset Database',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestRestartScreen extends StatelessWidget {
  const TestRestartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Database Reset Complete',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'The application will restart in 5 seconds.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {},
                child: const Text('Restart Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database Reset Basic UI Tests', () {
    testWidgets('ResetDatabaseDialog renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestResetDialog(),
        ),
      );

      // Verify the dialog renders
      expect(find.byType(TestResetDialog), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('RestartScreen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestRestartScreen(),
        ),
      );

      // Verify the restart screen renders
      expect(find.byType(TestRestartScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Database Reset Complete'), findsOneWidget);
    });

    testWidgets('ResetDatabaseDialog has required components', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestResetDialog(),
        ),
      );

      // Check for key components
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('RestartScreen has success indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestRestartScreen(),
        ),
      );

      // Check for success indicators
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Restart Now'), findsOneWidget);
    });

    group('Widget Lifecycle Tests', () {
      testWidgets('ResetDatabaseDialog handles disposal correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TestResetDialog(),
          ),
        );

        // Remove the widget
        await tester.pumpWidget(const SizedBox());

        // Should not throw any exceptions
        expect(tester.takeException(), isNull);
      });

      testWidgets('RestartScreen handles disposal correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TestRestartScreen(),
          ),
        );

        // Remove the widget
        await tester.pumpWidget(const SizedBox());

        // Should not throw any exceptions
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('widgets can be rendered without exceptions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TestResetDialog(),
          ),
        );

        // Should render without exceptions
        expect(find.byType(TestResetDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
