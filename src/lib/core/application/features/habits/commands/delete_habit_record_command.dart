import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

class DeleteHabitRecordCommand implements IRequest<DeleteHabitRecordCommandResponse> {
  final String id;

  DeleteHabitRecordCommand({required this.id});
}

class DeleteHabitRecordCommandResponse {}

class DeleteHabitRecordCommandHandler
    implements IRequestHandler<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;
  final IHabitRepository _habitRepository;

  DeleteHabitRecordCommandHandler({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
    required IHabitRepository habitRepository,
  })  : _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository,
        _habitRepository = habitRepository;

  @override
  Future<DeleteHabitRecordCommandResponse> call(DeleteHabitRecordCommand request) async {
    final habitRecord = await _habitRecordRepository.getById(request.id);
    if (habitRecord == null) {
      throw BusinessException('Habit record not found', HabitTranslationKeys.habitRecordNotFoundError);
    }

    final habit = await _habitRepository.getById(habitRecord.habitId);
    final isBadMarker = habit?.type == HabitType.bad && habitRecord.status == HabitRecordStatus.notDone;
    if (isBadMarker) {
      await _habitRecordRepository.delete(habitRecord);
      return DeleteHabitRecordCommandResponse();
    }

    // Delete ALL time records for the day
    final date = habitRecord.occurredAt;
    final startOfDay = DateTime.utc(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
      habitRecord.habitId,
      startOfDay,
      endOfDay,
    );

    for (final timeRecord in timeRecords) {
      await _habitTimeRecordRepository.delete(timeRecord);
    }

    // Delete the habit record
    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }
}
