import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:acore/acore.dart';

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
    final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));

    final filter = CustomWhereFilter(
        'habit_id = ? AND created_date >= ? AND created_date < ?', [request.habitId, startOfHour, endOfHour]);

    final existingRecord = await _habitTimeRecordRepository.getFirst(filter);

    if (existingRecord != null) {
      existingRecord.duration = request.totalDuration;
      await _habitTimeRecordRepository.update(existingRecord);
      return SaveHabitTimeRecordCommandResponse(id: existingRecord.id);
    }

    final habitTimeRecord = HabitTimeRecord(
      id: KeyHelper.generateStringId(),
      habitId: request.habitId,
      duration: request.totalDuration,
      createdDate: startOfHour, // Use hour bucket start time for consistency
      occurredAt: request.targetDate,
    );

    await _habitTimeRecordRepository.add(habitTimeRecord);
    return SaveHabitTimeRecordCommandResponse(id: habitTimeRecord.id);
  }
}
