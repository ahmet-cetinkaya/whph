import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/habits/queries/get_list_habits_query.dart';
import 'package:application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:domain/features/habits/habit_record_status.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_checkbox.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' hide Container;
import 'package:timezone/data/latest.dart' as tz;

class MockThemeService extends Mock implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  IThemeService? themeService;

  @override
  T resolve<T>([String? name]) {
    if (T == IThemeService) {
      if (themeService == null) {
        throw Exception('ThemeService not initialized in FakeContainer');
      }
      return themeService as T;
    }
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

void main() {
  late MockThemeService mockThemeService;
  late FakeContainer fakeContainer;

  setUpAll(() {
    tz.initializeTimeZones();
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    AppTheme.resetService();
    mockThemeService = MockThemeService();
    fakeContainer.themeService = mockThemeService;
  });
  Future<void> pumpWidget(
    WidgetTester tester, {
    required HabitListItem habit,
    List<HabitRecordListItem>? habitRecords,
    HabitListStyle style = HabitListStyle.list,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HabitCheckbox(
              habit: habit,
              habitRecords: habitRecords,
              style: style,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  group('HabitCheckbox', () {
    testWidgets('shows checkbox when style is list', (tester) async {
      final habit = HabitListItem(id: '1', name: 'Exercise');
      await pumpWidget(tester, habit: habit, habitRecords: [], style: HabitListStyle.list);

      expect(find.byIcon(Icons.close), findsOneWidget); // Visual representation (Close icon for not done/empty)
    });

    testWidgets('shows completed state when records meet target', (tester) async {
      final habit = HabitListItem(id: '1', name: 'Exercise', dailyTarget: 1);
      final today = DateTime.now();
      final records = [
        HabitRecordListItem(id: 'r1', date: today, occurredAt: today, status: HabitRecordStatus.complete),
      ];

      await pumpWidget(tester, habit: habit, habitRecords: records);

      // We expect the checkbox to be filled (check for color or icon)
      // Since it's hard to check color directly without extracting Container, we can check for logic results
      // e.g. finding Check icon if implemented, or just ensuring it renders without crashing.
      // In HabitCheckbox, if completed, it might show a check icon or just fill color.
      // Looking at implementation:
      // if (isCompleted) Icon(Icons.check, ...)

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      final habit = HabitListItem(id: '1', name: 'Exercise');

      await pumpWidget(tester, habit: habit, habitRecords: [], onTap: () {
        tapped = true;
      });

      await tester.tap(find.byType(HabitCheckbox));
      expect(tapped, isTrue);
    });

    testWidgets('shows count badge when multiple completions allowed', (tester) async {
      final habit = HabitListItem(id: '1', name: 'Water', dailyTarget: 5, hasGoal: true);
      final today = DateTime.now();
      final records = [
        HabitRecordListItem(id: 'r1', date: today, occurredAt: today, status: HabitRecordStatus.complete),
        HabitRecordListItem(id: 'r2', date: today, occurredAt: today, status: HabitRecordStatus.complete),
      ];

      await pumpWidget(tester, habit: habit, habitRecords: records);

      // Should show "2" in the badge
      expect(find.text('2'), findsOneWidget);
      // Or "2 / 5" depending on implementation.
      // Note: HabitCheckbox implementation logic:
      // if (hasCustomGoals && !isCompleted) -> Text('${todayCount}')
      // if completed -> check icon
    });
  });
}
