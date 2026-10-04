import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_details_content/controllers/habit_details_controller.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';

import 'habit_details_controller_type_test.mocks.dart';

void main() {
  const habitId = 'habit-1';
  const withinWindow = Duration(milliseconds: 50);

  late MockMediator mockMediator;
  late MockHabitsService mockHabitsService;
  late MockITranslationService mockTranslationService;
  late HabitDetailsController controller;
  late List<SaveHabitCommand> sent;
  late BuildContext context;

  GetHabitQueryResponse buildHabit({bool hasReminder = false}) {
    return GetHabitQueryResponse(
      id: habitId,
      createdDate: DateTime.utc(2026, 1, 1),
      type: HabitType.good,
      name: 'Scroll less',
      description: 'Original description',
      estimatedTime: 15,
      hasReminder: hasReminder,
      reminderTime: null,
      reminderDays: const [],
      hasGoal: true,
      targetFrequency: 3,
      periodDays: 7,
      dailyTarget: 2,
      statistics: HabitStatistics(
        overallScore: 0,
        monthlyScore: 0,
        yearlyScore: 0,
        totalRecords: 0,
        monthlyScores: const [],
        topStreaks: const [],
        yearlyFrequency: const {},
      ),
    );
  }

  Future<void> pumpAndLoad(WidgetTester tester, GetHabitQueryResponse? habit) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      }),
    ));
    if (habit == null) return;
    when(mockMediator.send<GetHabitQuery, GetHabitQueryResponse>(argThat(isA<GetHabitQuery>())))
        .thenAnswer((_) async => habit);
    await controller.loadHabit(habitId, context);
    await tester.pump();
  }

  setUp(() {
    mockMediator = MockMediator();
    mockHabitsService = MockHabitsService();
    mockTranslationService = MockITranslationService();
    sent = [];
    when(mockTranslationService.translate(any, namedArgs: anyNamed('namedArgs'))).thenReturn('translated');
    ErrorHelper.initialize(mockTranslationService);
    when(mockHabitsService.onHabitUpdated).thenReturn(ValueNotifier<String?>(null));
    when(mockHabitsService.onHabitRecordAdded).thenReturn(ValueNotifier<String?>(null));
    when(mockHabitsService.onHabitRecordRemoved).thenReturn(ValueNotifier<String?>(null));
    when(mockMediator.send<SaveHabitCommand, SaveHabitCommandResponse>(argThat(isA<SaveHabitCommand>())))
        .thenAnswer((i) async {
      sent.add(i.positionalArguments.first as SaveHabitCommand);
      return SaveHabitCommandResponse(id: habitId, createdDate: DateTime.utc(2026, 1, 1));
    });
    controller = HabitDetailsController(
      mediator: mockMediator,
      habitsService: mockHabitsService,
      translationService: mockTranslationService,
      soundManagerService: MockISoundManagerService(),
    );
  });

  group('HabitDetailsController flush on dispose', () {
    testWidgets('(a) name edit then dispose within the debounce saves the name once', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.updateName('X', habitId, context);
      await tester.pump(withinWindow);
      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
      expect(sent.single.name, 'X');
      expect(sent.single.description, 'Original description');
      expect(sent.single.estimatedTime, 15);
    });

    testWidgets('(b) description edit is saved on dispose', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.updateDescription('New desc', habitId, context);
      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
      expect(sent.single.description, 'New desc');
    });

    testWidgets('(b) estimated time edit is saved on dispose', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.updateEstimatedTime(42, habitId, context);
      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
      expect(sent.single.estimatedTime, 42);
    });

    testWidgets('(c) name then description within the window save once with both values', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.updateName('X', habitId, context);
      controller.updateDescription('D', habitId, context);
      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
      expect(sent.single.name, 'X');
      expect(sent.single.description, 'D');
    });

    testWidgets('(d) nothing pending sends nothing', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.dispose();
      await tester.pump();

      expect(sent, isEmpty);
    });

    testWidgets('normal debounce saves exactly once and dispose afterwards adds nothing', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      controller.updateName('X', habitId, context);
      await tester.pump(SharedUiConstants.contentSaveDebounceTime + withinWindow);
      expect(sent, hasLength(1));

      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
    });

    testWidgets('(e) dispose before the habit loaded sends nothing and does not throw', (tester) async {
      await pumpAndLoad(tester, null);
      controller.updateName('X', habitId, context);

      expect(() => controller.dispose(), returnsNormally);
      await tester.pump();

      expect(sent, isEmpty);
    });

    testWidgets('(f) a failing mediator during the flush does not throw out of dispose', (tester) async {
      await pumpAndLoad(tester, buildHabit());
      when(mockMediator.send<SaveHabitCommand, SaveHabitCommandResponse>(argThat(isA<SaveHabitCommand>())))
          .thenThrow(Exception('save failed'));
      controller.updateName('X', habitId, context);

      expect(() => controller.dispose(), returnsNormally);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('flush with hasReminder and null reminderTime builds a valid command', (tester) async {
      await pumpAndLoad(tester, buildHabit(hasReminder: true));
      controller.updateName('X', habitId, context);
      controller.dispose();
      await tester.pump();

      expect(sent, hasLength(1));
      expect(sent.single.hasReminder, isTrue);
      expect(sent.single.reminderTime, isNotNull);
      expect(sent.single.reminderDays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });
}
