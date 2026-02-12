import 'package:mediatr/mediatr.dart';
import 'package:application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:application/features/habits/services/habit_time_record_service.dart';

class SaveHabitTimeRecordCommand implements IRequest<SaveHabitTimeRecordCommandResponse> {
  final String habitId;
  final int totalDuration;
  final DateTime targetDate;

  SaveHabitTimeRecordCommand({
    required this.habitId,
    required this.totalDuration,
    required this.targetDate,
  });
}

class SaveHabitTimeRecordCommandResponse {
  final String id;

  SaveHabitTimeRecordCommandResponse({
    required this.id,
  });
}

class SaveHabitTimeRecordCommandHandler
    implements IRequestHandler<SaveHabitTimeRecordCommand, SaveHabitTimeRecordCommandResponse> {
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  SaveHabitTimeRecordCommandHandler({
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  }) : _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<SaveHabitTimeRecordCommandResponse> call(SaveHabitTimeRecordCommand request) async {
    final targetDate = request.targetDate.toUtc();

    final record = await HabitTimeRecordService.setTotalDurationForHabitTimeRecord(
      repository: _habitTimeRecordRepository,
      habitId: request.habitId,
      targetDate: targetDate,
      totalDuration: request.totalDuration,
    );

    return SaveHabitTimeRecordCommandResponse(id: record.id);
  }
}
