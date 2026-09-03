import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_details_content/controllers/habit_details_controller.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

import 'habit_details_controller_type_test.mocks.dart';

@GenerateMocks([
  Mediator,
  HabitsService,
  ITranslationService,
  ISoundManagerService,
])
void main() {
  const habitId = 'habit-1';

  late MockMediator mockMediator;
  late MockHabitsService mockHabitsService;
  late MockITranslationService mockTranslationService;
  late MockISoundManagerService mockSoundManagerService;
  late HabitDetailsController controller;
  late List<SaveHabitCommand> sentCommands;

  GetHabitQueryResponse buildHabit({
    HabitType type = HabitType.good,
    bool hasGoal = true,
    int targetFrequency = 3,
    int periodDays = 7,
    int? dailyTarget = 2,
    bool hasReminder = true,
    String? reminderTime = '08:30',
    List<int> reminderDays = const [1, 3, 5],
    DateTime? archivedDate,
  }) {
    return GetHabitQueryResponse(
      id: habitId,
      createdDate: DateTime.utc(2026, 1, 1),
      type: type,
      name: 'Scroll less',
      description: 'Original description',
      estimatedTime: 15,
      hasReminder: hasReminder,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
      hasGoal: hasGoal,
      targetFrequency: targetFrequency,
      periodDays: periodDays,
      dailyTarget: dailyTarget,
      archivedDate: archivedDate,
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

  Future<void> loadHabit(WidgetTester tester, GetHabitQueryResponse habit) async {
    when(mockMediator.send<GetHabitQuery, GetHabitQueryResponse>(argThat(isA<GetHabitQuery>())))
        .thenAnswer((_) async => habit);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await controller.loadHabit(habitId, capturedContext);
    await tester.pump();
  }

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return capturedContext;
  }

  setUp(() {
    mockMediator = MockMediator();
    mockHabitsService = MockHabitsService();
    mockTranslationService = MockITranslationService();
    mockSoundManagerService = MockISoundManagerService();
    sentCommands = [];

    when(mockTranslationService.translate(any, namedArgs: anyNamed('namedArgs'))).thenReturn('translated');
    when(mockHabitsService.onHabitUpdated).thenReturn(ValueNotifier<String?>(null));
    when(mockHabitsService.onHabitRecordAdded).thenReturn(ValueNotifier<String?>(null));
    when(mockHabitsService.onHabitRecordRemoved).thenReturn(ValueNotifier<String?>(null));

    when(mockMediator.send<SaveHabitCommand, SaveHabitCommandResponse>(argThat(isA<SaveHabitCommand>())))
        .thenAnswer((invocation) async {
      sentCommands.add(invocation.positionalArguments.first as SaveHabitCommand);
      return SaveHabitCommandResponse(id: habitId, createdDate: DateTime.utc(2026, 1, 1));
    });

    controller = HabitDetailsController(
      mediator: mockMediator,
      habitsService: mockHabitsService,
      translationService: mockTranslationService,
      soundManagerService: mockSoundManagerService,
    );
  });

  tearDown(() => controller.dispose());

  group('HabitDetailsController habit type', () {
    testWidgets('normalizes stale goal values for bad habit', (tester) async {
      await loadHabit(tester, buildHabit());
      final context = await pumpContext(tester);

      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      expect(sentCommands, hasLength(1), reason: 'Switching type must save immediately, not on debounce');
      final command = sentCommands.single;
      expect(command.type, HabitType.bad);
      expect(command.hasGoal, isFalse);
      expect(command.targetFrequency, 1);
      expect(command.periodDays, 1);
      expect(command.dailyTarget, 1);

      final habit = controller.habit!;
      expect(habit.type, HabitType.bad);
      expect(habit.hasGoal, isFalse);
      expect(habit.targetFrequency, 1);
      expect(habit.periodDays, 1);
      expect(habit.dailyTarget, 1);
    });

    testWidgets('preserves reminders and unrelated fields when switching to bad', (tester) async {
      await loadHabit(tester, buildHabit());
      final context = await pumpContext(tester);

      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      final command = sentCommands.single;
      expect(command.hasReminder, isTrue);
      expect(command.reminderTime, '08:30');
      expect(command.reminderDays, [1, 3, 5]);
      expect(command.name, 'Scroll less');
      expect(command.description, 'Original description');
      expect(command.estimatedTime, 15);
    });

    testWidgets('hides the goal field for bad habits and restores it for good', (tester) async {
      await loadHabit(tester, buildHabit());
      final context = await pumpContext(tester);

      expect(controller.isFieldVisible(HabitDetailsController.keyGoal), isTrue);

      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      expect(controller.isFieldVisible(HabitDetailsController.keyGoal), isFalse);
      expect(controller.shouldShowAsChip(HabitDetailsController.keyGoal), isFalse,
          reason: 'Bad habits must not offer the goal chip either');
      expect(controller.isFieldVisible(HabitDetailsController.keyReminder), isTrue,
          reason: 'Reminders stay available for bad habits');

      await controller.updateType(HabitType.good, habitId, context);
      await tester.pump();

      expect(controller.shouldShowAsChip(HabitDetailsController.keyGoal), isTrue,
          reason: 'Switching back exposes the goal control with normalized defaults');
    });

    testWidgets('switching back to good persists normalized goal defaults', (tester) async {
      await loadHabit(tester, buildHabit(type: HabitType.bad, hasGoal: false));
      final context = await pumpContext(tester);

      await controller.updateType(HabitType.good, habitId, context);
      await tester.pump();

      final command = sentCommands.single;
      expect(command.type, HabitType.good);
      expect(command.hasGoal, isFalse);
      expect(command.targetFrequency, 1);
      expect(command.periodDays, 1);
      expect(command.dailyTarget, 1);
      expect(controller.habit!.type, HabitType.good);
    });

    testWidgets('ignores a redundant switch to the active type', (tester) async {
      await loadHabit(tester, buildHabit(type: HabitType.bad, hasGoal: false));
      final context = await pumpContext(tester);

      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      expect(sentCommands, isEmpty);
    });

    testWidgets('archived habit rejects type changes', (tester) async {
      await loadHabit(tester, buildHabit(archivedDate: DateTime.utc(2026, 2, 1)));
      final context = await pumpContext(tester);

      expect(controller.isTypeReadOnly, isTrue);

      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      expect(sentCommands, isEmpty);
      expect(controller.habit!.type, HabitType.good);
      expect(controller.habit!.hasGoal, isTrue, reason: 'Archived habit fields must stay untouched');
    });

    testWidgets('reload round-trips the persisted type into the controller', (tester) async {
      await loadHabit(tester, buildHabit());
      expect(controller.habit!.type, HabitType.good);

      await loadHabit(tester, buildHabit(type: HabitType.bad, hasGoal: false, dailyTarget: 1));

      expect(controller.habit!.type, HabitType.bad,
          reason: 'Stale controller state must not survive a reload of a changed type');
      expect(controller.habit!.dailyTarget, 1);
    });
  });

  group('HabitDetailsController type as optional field', () {
    testWidgets('stays hidden and chip-offered for a good habit', (tester) async {
      await loadHabit(tester, buildHabit());

      expect(controller.isFieldVisible(HabitDetailsController.keyType), isFalse,
          reason: 'Good is the default type, so the selector must not clutter the table');
      expect(controller.shouldShowAsChip(HabitDetailsController.keyType), isTrue);
    });

    testWidgets('becomes visible when toggled through the chip', (tester) async {
      await loadHabit(tester, buildHabit());

      controller.toggleOptionalField(HabitDetailsController.keyType);
      await tester.pump();

      expect(controller.isFieldVisible(HabitDetailsController.keyType), isTrue);
      expect(controller.shouldShowAsChip(HabitDetailsController.keyType), isFalse);
    });

    testWidgets('is auto-visible for a bad habit', (tester) async {
      await loadHabit(tester, buildHabit(type: HabitType.bad, hasGoal: false));

      expect(controller.isFieldVisible(HabitDetailsController.keyType), isTrue,
          reason: 'A non-default type is content that must always be shown');
      expect(controller.shouldShowAsChip(HabitDetailsController.keyType), isFalse);
    });

    testWidgets('stays visible but read-only for an archived bad habit', (tester) async {
      await loadHabit(
        tester,
        buildHabit(type: HabitType.bad, hasGoal: false, archivedDate: DateTime.utc(2026, 2, 1)),
      );

      expect(controller.isFieldVisible(HabitDetailsController.keyType), isTrue);
      expect(controller.isTypeReadOnly, isTrue);
    });

    testWidgets('turns visible after switching a good habit to bad', (tester) async {
      await loadHabit(tester, buildHabit());
      final context = await pumpContext(tester);

      controller.toggleOptionalField(HabitDetailsController.keyType);
      await controller.updateType(HabitType.bad, habitId, context);
      await tester.pump();

      expect(controller.isFieldVisible(HabitDetailsController.keyType), isTrue);
      expect(controller.shouldShowAsChip(HabitDetailsController.keyType), isFalse,
          reason: 'Content-bearing fields are never offered back as a chip');
    });
  });
}
