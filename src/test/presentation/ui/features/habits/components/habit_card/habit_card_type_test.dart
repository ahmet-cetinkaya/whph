import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
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

  @override
  void notifyHabitRecordAdded(String habitId) => onHabitRecordAdded.value = habitId;
}

class _FakeTimeDataService extends Fake implements TimeDataService {
  @override
  void notifyTimeDataChanged() {}
}

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get surface1 => Colors.grey.shade100;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

/// Serves the record list the test set up and swaps in [recordsAfterToggle]
/// when the card issues a toggle, so the card re-reads a realistic post-toggle
/// world before deciding whether to play the completion sound.
class _ScriptedMediator extends Fake implements Mediator {
  _ScriptedMediator(this.records);

  List<HabitRecordListItem> records;
  List<HabitRecordListItem>? recordsAfterToggle;
  int toggleCallCount = 0;

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    if (request is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(
        items: List<HabitRecordListItem>.from(records),
        totalItemCount: records.length,
        pageIndex: 0,
        pageSize: records.length + 1,
      ) as R;
    }

    toggleCallCount++;
    final next = recordsAfterToggle;
    if (next != null) records = List<HabitRecordListItem>.from(next);
    return ToggleHabitCompletionCommandResponse() as R;
  }
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
  late _ScriptedMediator mediator;
  late _SpySoundManagerService soundManager;

  final today = DateTime.now();
  final longAgo = DateTime(2020, 1, 1);

  HabitRecordListItem recordOn(DateTime date, HabitRecordStatus status, {String id = 'r1'}) =>
      HabitRecordListItem(id: id, date: date, occurredAt: date, status: status);

  HabitListItem habitOf({
    HabitType type = HabitType.good,
    bool hasGoal = false,
    int? dailyTarget,
    DateTime? createdDate,
  }) =>
      HabitListItem(
        id: 'h1',
        name: 'Habit',
        type: type,
        hasGoal: hasGoal,
        dailyTarget: dailyTarget,
        targetFrequency: 1,
        periodDays: 1,
        createdDate: createdDate ?? longAgo,
      );

  setUpAll(() {
    tz.initializeTimeZones();
    container = _FakeContainer();
    app_main.container = container;
  });

  setUp(() {
    AppTheme.resetService();
    mediator = _ScriptedMediator([]);
    soundManager = _SpySoundManagerService();
    container.register<Mediator>(mediator);
    container.register<ISoundManagerService>(soundManager);
    container.register<HabitsService>(_FakeHabitsService());
    container.register<TimeDataService>(_FakeTimeDataService());
    container.register<ITranslationService>(_FakeTranslationService());
    container.register<IThemeService>(_FakeThemeService());
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required HabitListItem habit,
    List<HabitRecordListItem> records = const [],
    bool isThreeStateEnabled = false,
    HabitListStyle style = HabitListStyle.list,
    int dateRange = 7,
  }) async {
    mediator.records = List<HabitRecordListItem>.from(records);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitCard(
            habit: habit,
            onOpenDetails: () {},
            style: style,
            dateRange: dateRange,
            isThreeStateEnabled: isThreeStateEnabled,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color colorOfIcon(WidgetTester tester, IconData icon) => tester.widget<Icon>(find.byIcon(icon).first).color!;

  group('good habit rendering stays unchanged', () {
    testWidgets('complete day shows the green record icon', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(),
        records: [recordOn(today, HabitRecordStatus.complete)],
      );

      expect(find.byIcon(HabitUiConstants.recordIcon), findsOneWidget);
      expect(colorOfIcon(tester, HabitUiConstants.recordIcon), Colors.green);
    });

    testWidgets('incomplete day shows the red close icon', (tester) async {
      await pumpCard(tester, habit: habitOf());

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(colorOfIcon(tester, Icons.close), Colors.red);
    });

    testWidgets('partial day toward a daily target shows the blue add icon', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(hasGoal: true, dailyTarget: 3),
        records: [recordOn(today, HabitRecordStatus.complete)],
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(colorOfIcon(tester, Icons.add), Colors.blue);
    });

    testWidgets('three-state cycles an empty day to the neutral question mark', (tester) async {
      await pumpCard(tester, habit: habitOf(), isThreeStateEnabled: true);

      expect(find.byIcon(Icons.question_mark), findsOneWidget);
      expect(colorOfIcon(tester, Icons.question_mark), Colors.grey);
    });
  });

  group('bad habit rendering inverts the day meaning', () {
    testWidgets('applicable day without a failure renders success', (tester) async {
      await pumpCard(tester, habit: habitOf(type: HabitType.bad));

      expect(find.byIcon(HabitUiConstants.badSuccessIcon), findsOneWidget);
      expect(colorOfIcon(tester, HabitUiConstants.badSuccessIcon), HabitUiConstants.completedColor);
    });

    testWidgets('notDone day renders failure', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad),
        records: [recordOn(today, HabitRecordStatus.notDone)],
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(colorOfIcon(tester, Icons.close), HabitUiConstants.inCompletedColor);
    });

    testWidgets('a preserved complete record still renders success', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad),
        records: [recordOn(today, HabitRecordStatus.complete)],
      );

      expect(find.byIcon(HabitUiConstants.badSuccessIcon), findsOneWidget);
    });

    testWidgets('stays binary while the global three-state setting is enabled', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad),
        isThreeStateEnabled: true,
      );

      expect(find.byIcon(Icons.question_mark), findsNothing);
      expect(find.byIcon(HabitUiConstants.badSuccessIcon), findsOneWidget);
    });

    testWidgets('dates before creation render neutral in the card calendar', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad, createdDate: today),
        style: HabitListStyle.calendar,
        dateRange: 3,
      );

      // Today is applicable and successful; the two earlier days precede creation.
      expect(find.byIcon(HabitUiConstants.badSuccessIcon), findsOneWidget);
      expect(find.byIcon(HabitUiConstants.notApplicableIcon), findsNWidgets(2));
      final neutralColor = colorOfIcon(tester, HabitUiConstants.notApplicableIcon);
      expect(neutralColor, isNot(HabitUiConstants.completedColor));
      expect(neutralColor, isNot(HabitUiConstants.inCompletedColor));
    });
  });

  group('type-aware semantics', () {
    testWidgets('good habit exposes the completion hint', (tester) async {
      await pumpCard(tester, habit: habitOf());

      expect(find.bySemanticsLabel(HabitTranslationKeys.completeHabitHint), findsOneWidget);
    });

    testWidgets('bad habit success exposes the avoided status and perform action', (tester) async {
      await pumpCard(tester, habit: habitOf(type: HabitType.bad));

      final semantics = tester.getSemantics(find.bySemanticsLabel(HabitTranslationKeys.statusAvoided));
      expect(semantics.hint, HabitTranslationKeys.actionMarkPerformed);
    });

    testWidgets('bad habit failure exposes the performed status and undo action', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad),
        records: [recordOn(today, HabitRecordStatus.notDone)],
      );

      final semantics = tester.getSemantics(find.bySemanticsLabel(HabitTranslationKeys.statusPerformed));
      expect(semantics.hint, HabitTranslationKeys.actionUndo);
    });
  });

  group('completion sound fires only for a real good-habit success', () {
    Future<void> tapCheckbox(WidgetTester tester) async {
      await tester.tap(find.byType(InkWell).last);
      await tester.pumpAndSettle();
    }

    testWidgets('good habit reaching its target plays the sound once', (tester) async {
      await pumpCard(tester, habit: habitOf());
      mediator.recordsAfterToggle = [recordOn(today, HabitRecordStatus.complete)];

      await tapCheckbox(tester);

      expect(mediator.toggleCallCount, 1);
      expect(soundManager.habitCompletionCallCount, 1);
    });

    testWidgets('good habit undo stays silent', (tester) async {
      await pumpCard(tester, habit: habitOf(), records: [recordOn(today, HabitRecordStatus.complete)]);
      mediator.recordsAfterToggle = [];

      await tapCheckbox(tester);

      expect(mediator.toggleCallCount, 1);
      expect(soundManager.habitCompletionCallCount, 0);
    });

    testWidgets('recording a bad-habit failure stays silent', (tester) async {
      await pumpCard(tester, habit: habitOf(type: HabitType.bad));
      mediator.recordsAfterToggle = [recordOn(today, HabitRecordStatus.notDone)];

      await tapCheckbox(tester);

      expect(mediator.toggleCallCount, 1);
      expect(soundManager.habitCompletionCallCount, 0);
    });

    testWidgets('undoing a bad-habit failure stays silent', (tester) async {
      await pumpCard(
        tester,
        habit: habitOf(type: HabitType.bad),
        records: [recordOn(today, HabitRecordStatus.notDone)],
      );
      mediator.recordsAfterToggle = [];

      await tapCheckbox(tester);

      expect(mediator.toggleCallCount, 1);
      expect(soundManager.habitCompletionCallCount, 0);
    });
  });
}
