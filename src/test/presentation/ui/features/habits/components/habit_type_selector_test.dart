import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_type_selector.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    switch (key) {
      case HabitTranslationKeys.typeGood:
        return 'Good Habit';
      case HabitTranslationKeys.typeBad:
        return 'Bad Habit';
      case HabitTranslationKeys.typeLabel:
        return 'Habit Type';
      case HabitTranslationKeys.habitTypeHint:
        return 'Habit type';
      default:
        return key;
    }
  }
}

void main() {
  late MockTranslationService translationService;

  setUp(() {
    translationService = MockTranslationService();
  });

  Future<void> pumpSelector(
    WidgetTester tester, {
    required HabitType type,
    required ValueChanged<HabitType> onChanged,
    bool isReadOnly = false,
    Size surfaceSize = const Size(800, 600),
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitTypeSelector(
            type: type,
            onChanged: onChanged,
            isReadOnly: isReadOnly,
            translationService: translationService,
          ),
        ),
      ),
    );
  }

  group('HabitTypeSelector', () {
    testWidgets('preselects good and renders both translated options', (tester) async {
      await pumpSelector(tester, type: HabitType.good, onChanged: (_) {});

      final segmented = tester.widget<SegmentedButton<HabitType>>(find.byType(SegmentedButton<HabitType>));

      expect(segmented.selected, {HabitType.good});
      expect(find.text('Good Habit'), findsOneWidget);
      expect(find.text('Bad Habit'), findsOneWidget);
    });

    testWidgets('exposes an accessible semantics label for the control', (tester) async {
      await pumpSelector(tester, type: HabitType.good, onChanged: (_) {});

      expect(
        find.bySemanticsLabel('Habit type'),
        findsOneWidget,
        reason: 'Selector must carry a translated semantics label for screen readers',
      );
    });

    testWidgets('creates bad habit and edits back to good', (tester) async {
      final selections = <HabitType>[];
      var current = HabitType.good;

      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HabitTypeSelector(
                type: current,
                onChanged: (value) {
                  selections.add(value);
                  setState(() => current = value);
                },
                translationService: translationService,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Bad Habit'));
      await tester.pumpAndSettle();
      expect(selections, [HabitType.bad]);
      expect(
        tester.widget<SegmentedButton<HabitType>>(find.byType(SegmentedButton<HabitType>)).selected,
        {HabitType.bad},
      );

      await tester.tap(find.text('Good Habit'));
      await tester.pumpAndSettle();
      expect(selections, [HabitType.bad, HabitType.good]);
      expect(
        tester.widget<SegmentedButton<HabitType>>(find.byType(SegmentedButton<HabitType>)).selected,
        {HabitType.good},
      );
    });

    testWidgets('does not emit a change when the active type is tapped again', (tester) async {
      final selections = <HabitType>[];
      await pumpSelector(tester, type: HabitType.bad, onChanged: selections.add);

      await tester.tap(find.text('Bad Habit'));
      await tester.pumpAndSettle();

      expect(selections, isEmpty);
    });

    testWidgets('archived habit renders read-only and rejects interaction', (tester) async {
      final selections = <HabitType>[];
      await pumpSelector(
        tester,
        type: HabitType.bad,
        onChanged: selections.add,
        isReadOnly: true,
      );

      final segmented = tester.widget<SegmentedButton<HabitType>>(find.byType(SegmentedButton<HabitType>));
      expect(segmented.onSelectionChanged, isNull, reason: 'Read-only selector must disable selection');

      await tester.tap(find.text('Good Habit'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(segmented.selected, {HabitType.bad}, reason: 'Read-only selector must still show the persisted type');
    });

    testWidgets('renders without overflow on a narrow viewport', (tester) async {
      await pumpSelector(
        tester,
        type: HabitType.good,
        onChanged: (_) {},
        surfaceSize: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentedButton<HabitType>), findsOneWidget);
    });
  });
}
