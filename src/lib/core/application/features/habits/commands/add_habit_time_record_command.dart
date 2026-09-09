import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';

class AddHabitTimeRecordCommand implements IRequest<AddHabitTimeRecordCommandResponse> {
  final String habitId;
  final int duration;
  final DateTime? customDateTime;

  AddHabitTimeRecordCommand({
    required this.habitId,
    required this.duration,
    this.customDateTime,
  });
}

class AddHabitTimeRecordCommandResponse {
  final String id;

  AddHabitTimeRecordCommandResponse({
    required this.id,
  });
}

class AddHabitTimeRecordCommandHandler
    implements IRequestHandler<AddHabitTimeRecordCommand, AddHabitTimeRecordCommandResponse> {
  final IHabitTimeRecordRepository _habitTimeRecordRepository;
  final IHabitEvents? _habitEvents;

  AddHabitTimeRecordCommandHandler({
    required IHabitTimeRecordRepository habitTimeRecordRepository,
    IHabitEvents? habitEvents,
  })  : _habitTimeRecordRepository = habitTimeRecordRepository,
        _habitEvents = habitEvents;

  @override
  Future<AddHabitTimeRecordCommandResponse> call(AddHabitTimeRecordCommand request) async {
    final targetDate = request.customDateTime ?? DateTime.now().toUtc();

    final record = await HabitTimeRecordService.addDurationToHabitTimeRecord(
      repository: _habitTimeRecordRepository,
      habitId: request.habitId,
      targetDate: targetDate,
      durationToAdd: request.duration,
    );
    _habitEvents?.notifyHabitUpdated(request.habitId);

    return AddHabitTimeRecordCommandResponse(id: record.id);
  }
}
