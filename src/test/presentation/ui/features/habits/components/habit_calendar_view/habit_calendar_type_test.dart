import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habit_calendar_view/habit_calendar_view.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _SpySoundManagerService extends Fake implements ISoundManagerService {
  int habitCompletionCallCount = 0;

  @override
  Future<void> playHabitCompletion() async => habitCompletionCallCount++;
}

class _FakeHabitsService extends Fake implements HabitsService {
  @override
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier(null);
}

/// Returns short labels: the calendar card has a fixed 600px width, and echoing
/// full translation keys overflows its header row.
class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key.split('.').last;
}

class _FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get lightTextColor => Colors.white;
  @override
  Color get darkTextColor => Colors.black87;
  @override
  Color get surface0 => Colors.white;
  @override
  Color get surface1 => Colors.grey.shade100;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  Color get surface3 => Colors.grey.shade300;
  @override
  Color get dividerColor => Colors.grey.shade400;
  @override
  Color get barrierColor => Colors.black54;
  @override
  double get densityMultiplier => 1.0;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _registrations = {};

  void register<T extends Object>(T instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    final registration = _registrations[T];
    if (registration == null) throw StateError('Service not registered: $T');
    return registration as T;
  }
}

void main() {
  late _FakeContainer container;
  late _SpySoundManagerService soundManager;

  // A month fully in the past keeps every day applicable and free of "today" edges.
  final month = DateTime(2024, 5, 1);
  final createdDate = DateTime(2024, 5, 10);
  final archivedDate = DateTime(2024, 5, 20);

  HabitRecordListItem recordOn(int day, HabitRecordStatus status) => HabitRecordListItem(
        id: 'r$day',
        date: DateTime(2024, 5, day),
        occurredAt: DateTime(2024, 5, day),
        status: status,
      );

  setUpAll(() {
    tz.initializeTimeZones();
    container = _FakeContainer();
    app_main.container = container;
  });

  setUp(() {
    AppTheme.resetService();
    soundManager = _SpySoundManagerService();
    container.register<ISoundManagerService>(soundManager);
    container.register<HabitsService>(_FakeHabitsService());
    container.register<ITranslationService>(_FakeTranslationService());
    container.register<IThemeService>(_FakeThemeService());
  });

  Future<List<DateTime>> pumpCalendar(
    WidgetTester tester, {
    required HabitType habitType,
    List<HabitRecordListItem> records = const [],
    bool isThreeStateEnabled = false,
    DateTime? habitCreatedDate,
    DateTime? habitArchivedDate,
    void Function(DateTime)? onToggle,
  }) async {
    final toggled = <DateTime>[];
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitCalendarView(
              habitId: 'h1',
              habitType: habitType,
              createdDate: habitCreatedDate ?? DateTime(2020, 1, 1),
              archivedDate: habitArchivedDate,
              currentMonth: month,
              records: records,
              onToggle: (date) {
                toggled.add(date);
                onToggle?.call(date);
              },
              onPreviousMonth: () {},
              onNextMonth: () {},
              isThreeStateEnabled: isThreeStateEnabled,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return toggled;
  }

  Finder dayCell(int day) => find.ancestor(
        of: find.text('$day'),
        matching: find.byType(OutlinedButton),
      );

  Finder iconInDay(int day, IconData icon) => find.descendant(of: dayCell(day), matching: find.byIcon(icon));

  Color iconColorInDay(WidgetTester tester, int day, IconData icon) =>
      tester.widget<Icon>(iconInDay(day, icon).first).color!;

  group('good habit month rendering stays unchanged', () {
    testWidgets('complete day renders the green record icon', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.good,
        records: [recordOn(12, HabitRecordStatus.complete)],
      );

      expect(iconInDay(12, HabitUiConstants.recordIcon), findsOneWidget);
      expect(iconColorInDay(tester, 12, HabitUiConstants.recordIcon), Colors.green);
    });

    testWidgets('notDone day renders the red close icon', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.good,
        records: [recordOn(12, HabitRecordStatus.notDone)],
      );

      expect(iconInDay(12, Icons.close), findsOneWidget);
      expect(iconColorInDay(tester, 12, Icons.close), Colors.red);
    });

    testWidgets('three-state renders an empty day as the neutral question mark', (tester) async {
      await pumpCalendar(tester, habitType: HabitType.good, isThreeStateEnabled: true);

      expect(iconInDay(12, Icons.question_mark), findsOneWidget);
    });
  });

  group('bad habit month rendering', () {
    testWidgets('renders mixed good and bad month states', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.bad,
        habitCreatedDate: createdDate,
        habitArchivedDate: archivedDate,
        records: [
          recordOn(12, HabitRecordStatus.notDone),
          recordOn(14, HabitRecordStatus.complete),
        ],
      );

      // Before creation: neutral.
      expect(iconInDay(5, HabitUiConstants.notApplicableIcon), findsOneWidget);
      // Applicable with a failure: failure.
      expect(iconInDay(12, Icons.close), findsOneWidget);
      expect(iconColorInDay(tester, 12, Icons.close), HabitUiConstants.inCompletedColor);
      // Applicable, preserved complete history but no failure: success.
      expect(iconInDay(14, HabitUiConstants.badSuccessIcon), findsOneWidget);
      // Applicable and empty: success.
      expect(iconInDay(15, HabitUiConstants.badSuccessIcon), findsOneWidget);
      expect(iconColorInDay(tester, 15, HabitUiConstants.badSuccessIcon), HabitUiConstants.completedColor);
      // After archive: neutral.
      expect(iconInDay(25, HabitUiConstants.notApplicableIcon), findsOneWidget);
    });

    testWidgets('stays binary while the global three-state setting is enabled', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.bad,
        habitCreatedDate: createdDate,
        isThreeStateEnabled: true,
      );

      expect(iconInDay(15, Icons.question_mark), findsNothing);
      expect(iconInDay(15, HabitUiConstants.badSuccessIcon), findsOneWidget);
    });

    testWidgets('non-applicable days are not tappable', (tester) async {
      final toggled = await pumpCalendar(
        tester,
        habitType: HabitType.bad,
        habitCreatedDate: createdDate,
      );

      await tester.tap(dayCell(5), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(toggled, isEmpty);
    });
  });

  group('completion sound fires only for a real good-habit success', () {
    testWidgets('good habit day toggle plays the sound', (tester) async {
      await pumpCalendar(tester, habitType: HabitType.good);

      await tester.tap(dayCell(12));
      await tester.pumpAndSettle();

      expect(soundManager.habitCompletionCallCount, 1);
    });

    testWidgets('recording a bad-habit failure stays silent', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.bad,
        habitCreatedDate: createdDate,
      );

      await tester.tap(dayCell(15));
      await tester.pumpAndSettle();

      expect(soundManager.habitCompletionCallCount, 0);
    });

    testWidgets('undoing a bad-habit failure stays silent', (tester) async {
      await pumpCalendar(
        tester,
        habitType: HabitType.bad,
        habitCreatedDate: createdDate,
        records: [recordOn(15, HabitRecordStatus.notDone)],
      );

      await tester.tap(dayCell(15));
      await tester.pumpAndSettle();

      expect(soundManager.habitCompletionCallCount, 0);
    });
  });
}
