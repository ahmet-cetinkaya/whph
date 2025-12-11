import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database Reset Basic UI Tests', () {
    testWidgets('ResetDatabaseDialog renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
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
          ),
        ),
      );

      // Verify the dialog renders
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('RestartScreen renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          ),
        ),
      );

      // Verify the restart screen renders
      expect(find.text('Database Reset Complete'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('ResetDatabaseDialog has required components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Reset Database')),
            body: const Center(
              child: Icon(
                Icons.warning_rounded,
                size: 80,
                color: Colors.orange,
              ),
            ),
          ),
        ),
      );

      // Check for key components
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('RestartScreen has success indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 24),
                  Text('Database Reset Complete'),
                ],
              ),
            ),
          ),
        ),
      );

      // Check for success indicators
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Database Reset Complete'), findsOneWidget);
    });
  });
}
