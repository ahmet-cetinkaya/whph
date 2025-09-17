import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
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

  DeleteHabitRecordCommandHandler({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<DeleteHabitRecordCommandResponse> call(DeleteHabitRecordCommand request) async {
    final habitRecord = await _habitRecordRepository.getById(request.id);
    if (habitRecord == null) {
      throw BusinessException('Habit record not found', HabitTranslationKeys.habitRecordNotFoundError);
    }

    // Delete ALL time records for the day
    final date = habitRecord.occurredAt;
    final startOfDay = DateTime.utc(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final timeRecords = await _habitTimeRecordRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'habit_id = ? AND ((occurred_at >= ? AND occurred_at < ?) OR (occurred_at IS NULL AND created_date >= ? AND created_date < ?))',
        [habitRecord.habitId, startOfDay, endOfDay, startOfDay, endOfDay]
      )
    );

    for (final timeRecord in timeRecords) {
      await _habitTimeRecordRepository.delete(timeRecord);
    }

    // Delete the habit record
    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }
}
