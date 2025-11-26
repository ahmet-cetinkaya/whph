import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:acore/components/date_time_picker/quick_range_selector.dart';
import 'package:acore/components/date_time_picker/date_time_picker_translation_keys.dart';

void main() {
  group('QuickRangeSelector Widget Tests', () {
    late List<QuickDateRange> mockQuickRanges;

    setUp(() {
      final now = DateTime.now();
      mockQuickRanges = [
        QuickDateRange(
          key: 'today',
          label: 'Today',
          startDateCalculator: () => now,
          endDateCalculator: () => now,
        ),
        QuickDateRange(
          key: 'tomorrow',
          label: 'Tomorrow',
          startDateCalculator: () => now.add(const Duration(days: 1)),
          endDateCalculator: () => now.add(const Duration(days: 1)),
        ),
      ];
    });

    testWidgets('QuickRangeSelector renders correctly with ranges', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRangeSelector(
              quickRanges: mockQuickRanges,
              selectedQuickRangeKey: 'today',
              showQuickRanges: true,
              showRefreshToggle: false,
              refreshEnabled: false,
              translations: {
                DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
                DateTimePickerTranslationKey.quickSelectionTitle: 'Quick Selection',
              },
              onQuickRangeSelected: (QuickDateRange range) {},
              hasSelection: true,
            ),
          ),
        ),
      );

      // Verify the component renders
      expect(find.byType(QuickRangeSelector), findsOneWidget);
      expect(find.text('Quick Selection'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('QuickRangeSelector handles keyboard navigation', (WidgetTester tester) async {
      String? selectedKey = 'today';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRangeSelector(
              quickRanges: mockQuickRanges,
              selectedQuickRangeKey: selectedKey,
              showQuickRanges: true,
              showRefreshToggle: false,
              refreshEnabled: false,
              translations: {
                DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
              },
              onQuickRangeSelected: (QuickDateRange range) {
                selectedKey = range.key;
              },
              hasSelection: true,
            ),
          ),
        ),
      );

      // Focus the quick selection button and press Enter
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Verify component still exists
      expect(find.byType(QuickRangeSelector), findsOneWidget);
    });

    testWidgets('QuickRangeSelector shows clear button when has selection', (WidgetTester tester) async {
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRangeSelector(
              quickRanges: mockQuickRanges,
              selectedQuickRangeKey: 'today',
              showQuickRanges: true,
              showRefreshToggle: false,
              refreshEnabled: false,
              translations: {
                DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
              },
              onQuickRangeSelected: (QuickDateRange range) {},
              onClear: () {
                clearCalled = true;
              },
              hasSelection: true,
            ),
          ),
        ),
      );

      // Verify clear button exists
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(clearCalled, isTrue);
    });

    testWidgets('QuickRangeSelector handles empty ranges gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRangeSelector(
              quickRanges: [],
              selectedQuickRangeKey: null,
              showQuickRanges: true,
              showRefreshToggle: false,
              refreshEnabled: false,
              translations: {
                DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
              },
              onQuickRangeSelected: (QuickDateRange range) {},
              hasSelection: false,
            ),
          ),
        ),
      );

      // Should render without crashing but show no content
      expect(find.byType(QuickRangeSelector), findsOneWidget);
      expect(find.text('Quick Selection'), findsNothing);
    });

    testWidgets('QuickRangeSelector provides proper semantic labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRangeSelector(
              quickRanges: mockQuickRanges,
              selectedQuickRangeKey: 'today',
              showQuickRanges: true,
              showRefreshToggle: false,
              refreshEnabled: false,
              translations: {
                DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
              },
              onQuickRangeSelected: (QuickDateRange range) {},
              hasSelection: true,
            ),
          ),
        ),
      );

      // Check for semantic button label
      expect(
        find.bySemanticsLabel(RegExp(r'Currently selected:.*Tap to change selection.')),
        findsOneWidget,
      );

      // Check for clear button semantic label
      expect(
        find.bySemanticsLabel('Clear selection'),
        findsOneWidget,
      );
    });

    group('QuickRangeSelector Accessibility Tests', () {
      testWidgets('QuickRangeSelector buttons are keyboard navigable', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickRangeSelector(
                quickRanges: mockQuickRanges,
                selectedQuickRangeKey: 'today',
                showQuickRanges: true,
                showRefreshToggle: false,
                refreshEnabled: false,
                translations: {
                  DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
                },
                onQuickRangeSelected: (QuickDateRange range) {},
                hasSelection: true,
              ),
            ),
          ),
        );

        // Test keyboard navigation on quick selection button
        await tester.tap(find.byType(OutlinedButton).first);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        // Test keyboard navigation on clear button
        await tester.tap(find.byType(OutlinedButton).last);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pump();

        expect(find.byType(QuickRangeSelector), findsOneWidget);
      });
    });

    group('QuickRangeSelector Performance Tests', () {
      testWidgets('QuickRangeSelector renders efficiently', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickRangeSelector(
                quickRanges: mockQuickRanges,
                selectedQuickRangeKey: 'today',
                showQuickRanges: true,
                showRefreshToggle: false,
                refreshEnabled: false,
                translations: {
                  DateTimePickerTranslationKey.quickSelection: 'Quick Selection',
                },
                onQuickRangeSelected: (QuickDateRange range) {},
                hasSelection: true,
              ),
            ),
          ),
        );

        stopwatch.stop();

        // Should render within reasonable time (less than 100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(find.byType(QuickRangeSelector), findsOneWidget);
      });
    });
  });
}
