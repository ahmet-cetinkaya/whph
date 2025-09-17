import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:acore/acore.dart';

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

  AddHabitTimeRecordCommandHandler({
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  }) : _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<AddHabitTimeRecordCommandResponse> call(AddHabitTimeRecordCommand request) async {
    final targetDate = request.customDateTime ?? DateTime.now().toUtc();
    final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));

    final filter = CustomWhereFilter(
        'habit_id = ? AND created_date >= ? AND created_date < ?', [request.habitId, startOfHour, endOfHour]);

    final existingRecord = await _habitTimeRecordRepository.getFirst(filter);

    if (existingRecord != null) {
      existingRecord.duration += request.duration;
      await _habitTimeRecordRepository.update(existingRecord);
      return AddHabitTimeRecordCommandResponse(id: existingRecord.id);
    }

    final habitTimeRecord = HabitTimeRecord(
      id: KeyHelper.generateStringId(),
      habitId: request.habitId,
      duration: request.duration,
      createdDate: startOfHour, // Use hour bucket start time for consistency
      occurredAt: request.customDateTime ?? DateTime.now().toUtc(),
    );

    await _habitTimeRecordRepository.add(habitTimeRecord);
    return AddHabitTimeRecordCommandResponse(id: habitTimeRecord.id);
  }
}
