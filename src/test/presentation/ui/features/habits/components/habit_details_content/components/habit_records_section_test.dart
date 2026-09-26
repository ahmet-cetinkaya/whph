// Regression test for: the habit-details title-row toggle button always
// showed a red X and appeared to do nothing for "bad" habits. Root cause:
// `HabitRecordsSection.buildDailyRecordButton` only ever branched on
// `HabitRecordStatus` (complete/notDone/skipped), a mapping designed for
// "good" habits. Bad habits never produce a `complete` record (see
// `ToggleHabitCompletionCommandHandler.toggleBadHabitMarker`), so both of a
// bad habit's real states - "avoided" (no record) and "performed" (a notDone
// record exists) - fell into the same red-X branch, making the button look
// broken even though the underlying toggle worked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_details_content/components/habit_records_section.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
}

HabitRecordListItem _record(DateTime date, HabitRecordStatus status) => HabitRecordListItem(
      id: 'r-${date.toIso8601String()}-$status',
      date: DateTime(date.year, date.month, date.day),
      occurredAt: date,
      status: status,
    );

Icon _iconOf(Widget widget) =>
    find.descendant(of: find.byWidget(widget), matching: find.byType(Icon)).evaluate().single.widget as Icon;

void main() {
  const habitId = 'habit-1';
  final createdDate = DateTime(2026, 1, 1);

  Future<Icon> pumpButton(
    WidgetTester tester, {
    required HabitType habitType,
    required HabitRecordStatus todayStatus,
    List<HabitRecordListItem>? records,
    bool isArchived = false,
  }) async {
    late Widget button;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        button = HabitRecordsSection.buildDailyRecordButton(
          context: context,
          dailyCompletionCount: records?.where((r) => r.status == HabitRecordStatus.complete).length ?? 0,
          todayStatus: todayStatus,
          hasCustomGoals: false,
          dailyTarget: 1,
          isArchived: isArchived,
          translationService: FakeTranslationService(),
          themeService: FakeThemeService(),
          onToggle: () {},
          habitType: habitType,
          habitId: habitId,
          createdDate: createdDate,
          archivedDate: null,
          records: records,
        );
        return Scaffold(body: button);
      }),
    ));

    return _iconOf(button);
  }

  group('bad habit - title row button', () {
    testWidgets('with no record today shows the positive "avoided" indicator, not a red X', (tester) async {
      final icon = await pumpButton(
        tester,
        habitType: HabitType.bad,
        todayStatus: HabitRecordStatus.skipped,
        records: const [],
      );

      expect(icon.icon, HabitUiConstants.badSuccessIcon,
          reason: 'No violation recorded today means the bad habit was successfully avoided');
      expect(icon.color, HabitUiConstants.completedColor);
    });

    testWidgets('with a notDone record today shows the failure indicator', (tester) async {
      final today = DateTime.now();
      final icon = await pumpButton(
        tester,
        habitType: HabitType.bad,
        todayStatus: HabitRecordStatus.notDone,
        records: [_record(today, HabitRecordStatus.notDone)],
      );

      expect(icon.icon, HabitUiConstants.noRecordIcon);
      expect(icon.color, HabitUiConstants.inCompletedColor);
    });

    testWidgets('avoided and performed states render visibly different icons (the actual bug)', (tester) async {
      final today = DateTime.now();

      final avoided = await pumpButton(
        tester,
        habitType: HabitType.bad,
        todayStatus: HabitRecordStatus.skipped,
        records: const [],
      );
      final performed = await pumpButton(
        tester,
        habitType: HabitType.bad,
        todayStatus: HabitRecordStatus.notDone,
        records: [_record(today, HabitRecordStatus.notDone)],
      );

      expect(avoided.icon != performed.icon || avoided.color != performed.color, isTrue,
          reason: 'Before the fix, both states rendered as a red X, making the button look stuck/broken');
    });
  });

  group('good habit - title row button (unchanged behavior)', () {
    testWidgets('complete status shows the green check/link icon', (tester) async {
      final icon = await pumpButton(
        tester,
        habitType: HabitType.good,
        todayStatus: HabitRecordStatus.complete,
      );

      expect(icon.icon, HabitUiConstants.recordIcon);
      expect(icon.color, Colors.green);
    });

    testWidgets('skipped status (default, three-state off) shows the red X', (tester) async {
      final icon = await pumpButton(
        tester,
        habitType: HabitType.good,
        todayStatus: HabitRecordStatus.skipped,
      );

      expect(icon.icon, Icons.close);
      expect(icon.color, Colors.red.withValues(alpha: 0.7));
    });
  });
}
