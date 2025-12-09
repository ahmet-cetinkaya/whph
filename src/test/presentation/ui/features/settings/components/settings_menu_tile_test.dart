import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';

void main() {
  group('SettingsMenuTile Widget Tests', () {
    testWidgets('renders title and icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Setting'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              subtitle: 'Subtitle text',
              icon: Icons.settings,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Setting'), findsOneWidget);
      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('handles tap callback', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Setting'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('uses custom trailing widget when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              onTap: () {},
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      // Default chevron should not appear
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('shows default chevron when no trailing provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('uses custom leading widget when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              onTap: () {},
              customLeading: Icon(Icons.widgets),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.widgets), findsOneWidget);
      // Icon should not appear when customLeading is used
      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('applies active state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              isActive: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify the tile is rendered with active state
      final settingsTile = tester.widget<SettingsMenuTile>(find.byType(SettingsMenuTile));
      expect(settingsTile.isActive, isTrue);
    });

    testWidgets('asserts when neither icon nor customLeading is provided', (WidgetTester tester) async {
      expect(
        () => SettingsMenuTile(
          title: 'Test Setting',
          onTap: () {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('uses custom icon size when provided', (WidgetTester tester) async {
      const customIconSize = 32.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsMenuTile(
              title: 'Test Setting',
              icon: Icons.settings,
              iconSize: customIconSize,
              onTap: () {},
            ),
          ),
        ),
      );

      final settingsTile = tester.widget<SettingsMenuTile>(find.byType(SettingsMenuTile));
      expect(settingsTile.iconSize, equals(customIconSize));
    });
  });
}
