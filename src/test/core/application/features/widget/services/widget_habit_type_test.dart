import 'package:acore/acore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/application/features/widget/models/widget_data.dart';
import 'package:whph/core/application/features/widget/services/widget_service/widget_service.dart';
import 'package:whph/core/application/features/widget/services/widget_service/helpers/widget_background_callback_handler.dart';
import 'package:whph/core/application/features/widget/services/widget_service/helpers/widget_toggle_helper.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('widget habit payload', () {
    test('serializes habit type and derived daily state', () {
      final data = WidgetData(
        tasks: const [],
        habits: [
          WidgetHabitData(
            id: 'bad-habit',
            name: 'No smoking',
            type: HabitType.bad,
            dailyState: HabitDayState.successful,
            isCompletedToday: true,
          ),
        ],
        lastUpdated: DateTime.utc(2026, 9, 2),
        tasksTitle: 'Tasks',
        habitsTitle: 'Habits',
        noPendingTasks: 'None',
        noPendingHabits: 'None',
        todayLabel: 'Today',
      );

      final habitJson = (data.toJson()['habits'] as List).single as Map<String, dynamic>;

      expect(habitJson['type'], HabitType.bad.name);
      expect(habitJson['dailyState'], HabitDayState.successful.name);
      expect(habitJson['isCompletedToday'], isTrue);
    });

    test('round-trips habit type and derived daily state', () {
      final habit = WidgetHabitData(
        id: 'bad-habit',
        name: 'No smoking',
        type: HabitType.bad,
        dailyState: HabitDayState.failed,
        isCompletedToday: false,
      );

      final decoded = WidgetHabitData.fromJson(habit.toJson());

      expect(decoded.type, HabitType.bad);
      expect(decoded.dailyState, HabitDayState.failed);
    });

    test('legacy habit payload defaults missing type and daily state', () {
      final decoded = WidgetHabitData.fromJson({
        'id': 'legacy-habit',
        'name': 'Legacy habit',
        'isCompletedToday': false,
      });

      expect(decoded.type, HabitType.good);
      expect(decoded.dailyState, HabitDayState.incomplete);
    });

    test('unrecognized habit type and daily state fall back to defaults', () {
      final decoded = WidgetHabitData.fromJson({
        'id': 'forward-compatible-habit',
        'name': 'Written by a newer app version',
        'type': 'neutral',
        'dailyState': 'skipped',
        'isCompletedToday': false,
      });

      expect(decoded.type, HabitType.good);
      expect(decoded.dailyState, HabitDayState.incomplete);
    });
  });

  group('widget habit actions', () {
    const homeWidgetChannel = MethodChannel('home_widget');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, null);
    });

    test('foreground bad failure and undo emit no completion feedback', () async {
      final mediator = _HabitMediator(type: HabitType.bad);
      final sound = _SoundSpy();
      final feedbackPayloads = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(homeWidgetChannel,
          (call) async {
        if (call.method == 'saveWidgetData' &&
            call.arguments is Map &&
            (call.arguments as Map)['id'] == 'widget_data') {
          feedbackPayloads.add((call.arguments as Map)['data'] as String);
        }
        return true;
      });
      final service = WidgetService(
        mediator: mediator,
        container: _SoundContainer(sound),
      );

      await service.handleWidgetClick('toggle_habit', 'habit');
      await service.handleWidgetClick('toggle_habit', 'habit');

      expect(
        feedbackPayloads.where((payload) => payload.contains('Habit completed! ✓')),
        isEmpty,
      );
      expect(sound.playCount, 0);
    });

    test('foreground good habit keeps completion feedback', () async {
      final mediator = _HabitMediator(type: HabitType.good);
      final feedbackPayloads = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(homeWidgetChannel,
          (call) async {
        if (call.method == 'saveWidgetData' &&
            call.arguments is Map &&
            (call.arguments as Map)['id'] == 'widget_data') {
          feedbackPayloads.add((call.arguments as Map)['data'] as String);
        }
        return true;
      });
      final service = WidgetService(
        mediator: mediator,
        container: _SoundContainer(_SoundSpy()),
      );

      await service.handleWidgetClick('toggle_habit', 'habit');

      expect(
        feedbackPayloads.where((payload) => payload.contains('Habit completed! ✓')),
        hasLength(1),
      );
    });

    test('keeps good-habit incremental target behavior', () async {
      final mediator = _HabitMediator(type: HabitType.good, dailyTarget: 2);
      final helper = WidgetToggleHelper(mediator: mediator);

      await helper.toggleHabit('habit');
      await helper.toggleHabit('habit');

      expect(mediator.statuses, [HabitRecordStatus.complete, HabitRecordStatus.complete]);
    });

    test('foreground and background bad failure and undo play no sound', () async {
      final foreground = _HabitMediator(type: HabitType.bad);
      final background = _HabitMediator(type: HabitType.bad);
      final foregroundSound = _SoundSpy();
      final backgroundSound = _SoundSpy();

      final foregroundService = WidgetService(
        mediator: foreground,
        container: _SoundContainer(foregroundSound),
      );
      await foregroundService.handleWidgetClick('toggle_habit', 'habit');
      await foregroundService.handleWidgetClick('toggle_habit', 'habit');
      await backgroundToggleHabit(background, _SoundContainer(backgroundSound), 'habit');
      await backgroundToggleHabit(background, _SoundContainer(backgroundSound), 'habit');

      expect(foreground.statuses, isEmpty);
      expect(background.statuses, foreground.statuses);
      expect(foregroundSound.playCount, 0);
      expect(backgroundSound.playCount, 0);
    });

    test('repeated bad-habit failure recording leaves exactly one notDone', () async {
      final mediator = _HabitMediator(
        type: HabitType.bad,
        initialStatuses: [HabitRecordStatus.complete],
      );
      final helper = WidgetToggleHelper(mediator: mediator);

      await helper.toggleHabit('habit');

      expect(mediator.statuses.where((status) => status == HabitRecordStatus.notDone), hasLength(1));
      expect(mediator.statuses.where((status) => status == HabitRecordStatus.complete), hasLength(1));
    });

    test('widget undo preserves historical complete records', () async {
      final foreground = _HabitMediator(
        type: HabitType.bad,
        initialStatuses: [HabitRecordStatus.complete, HabitRecordStatus.notDone],
      );
      final background = _HabitMediator(
        type: HabitType.bad,
        initialStatuses: [HabitRecordStatus.complete, HabitRecordStatus.notDone],
      );

      await WidgetToggleHelper(mediator: foreground).toggleHabit('habit');
      await backgroundToggleHabit(background, _SoundContainer(_SoundSpy()), 'habit');

      expect(foreground.statuses, [HabitRecordStatus.complete]);
      expect(background.statuses, foreground.statuses);
    });
  });
}

class _HabitMediator implements Mediator {
  _HabitMediator({
    required this.type,
    this.dailyTarget = 1,
    List<HabitRecordStatus> initialStatuses = const [],
  }) : _records = [
          for (final (index, status) in initialStatuses.indexed)
            HabitRecordListItem(
              id: 'record-$index',
              date: DateTime.now(),
              occurredAt: DateTime.now(),
              status: status,
            ),
        ];

  final HabitType type;
  final int dailyTarget;
  List<HabitRecordListItem> _records;

  List<HabitRecordStatus> get statuses => _records.map((record) => record.status).toList();

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest request) async {
    switch (request) {
      case GetHabitQuery():
        return GetHabitQueryResponse(
          id: 'habit',
          createdDate: DateTime(2026),
          type: type,
          name: 'Habit',
          description: '',
          hasGoal: dailyTarget > 1,
          dailyTarget: dailyTarget,
          statistics: HabitStatistics(
            overallScore: 0,
            monthlyScore: 0,
            yearlyScore: 0,
            totalRecords: 0,
            monthlyScores: const [],
            topStreaks: const [],
            yearlyFrequency: const {},
          ),
        ) as TResponse;
      case GetListHabitRecordsQuery():
        return GetListHabitRecordsQueryResponse(
          items: List.unmodifiable(_records),
          totalItemCount: _records.length,
          pageIndex: 0,
          pageSize: 20,
        ) as TResponse;
      case ToggleHabitCompletionCommand():
        _toggle(request as ToggleHabitCompletionCommand);
        return ToggleHabitCompletionCommandResponse() as TResponse;
      case DeleteHabitRecordCommand():
        final command = request as DeleteHabitRecordCommand;
        _records = _records.where((record) => record.id != command.id).toList();
        return DeleteHabitRecordCommandResponse() as TResponse;
      default:
        throw UnimplementedError('$request');
    }
  }

  void _toggle(ToggleHabitCompletionCommand request) {
    if (type == HabitType.bad) {
      final failures = _records.where((record) => record.status == HabitRecordStatus.notDone).toList();
      _records = failures.isEmpty
          ? [
              ..._records,
              HabitRecordListItem(
                id: 'failure',
                date: request.date,
                occurredAt: request.date,
                status: HabitRecordStatus.notDone,
              ),
            ]
          : _records.where((record) => record.status != HabitRecordStatus.notDone).toList();
      return;
    }

    _records = [
      ..._records,
      HabitRecordListItem(
        id: 'complete-${_records.length}',
        date: request.date,
        occurredAt: request.date,
        status: HabitRecordStatus.complete,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SoundContainer implements IContainer {
  const _SoundContainer(this.sound);

  final ISoundManagerService sound;

  @override
  T resolve<T>([String? name]) {
    if (T == ISoundManagerService) return sound as T;
    throw StateError('No registration for $T');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SoundSpy implements ISoundManagerService {
  int playCount = 0;

  @override
  Future<void> playHabitCompletion() async => playCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
