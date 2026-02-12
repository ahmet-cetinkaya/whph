import 'package:mediatr/mediatr.dart';
import 'package:application/features/habits/services/i_habit_record_repository.dart';
import 'package:application/features/habits/services/i_habit_repository.dart';
import 'package:application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:application/features/habits/services/habit_time_record_service.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:acore/acore.dart';

class AddHabitRecordCommand implements IRequest<AddHabitRecordCommandResponse> {
  final String habitId;
  final DateTime occurredAt;

  AddHabitRecordCommand({
    required this.habitId,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt != null ? DateTimeHelper.toUtcDateTime(occurredAt) : DateTime.now().toUtc();
}

class AddHabitRecordCommandResponse {}

class AddHabitRecordCommandHandler implements IRequestHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitRepository _habitRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  AddHabitRecordCommandHandler({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitRepository habitRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRecordRepository = habitRecordRepository,
        _habitRepository = habitRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<AddHabitRecordCommandResponse> call(AddHabitRecordCommand request) async {
    // Create the habit record
    await _habitRecordRepository.add(HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      habitId: request.habitId,
      occurredAt: request.occurredAt,
    ));

    // Add estimated time if habit has it
    final habit = await _habitRepository.getById(request.habitId);
    if (habit?.estimatedTime != null && habit!.estimatedTime! > 0) {
      await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
        repository: _habitTimeRecordRepository,
        habitId: request.habitId,
        targetDate: request.occurredAt,
        estimatedDuration: habit.estimatedTime! * 60,
      );
    }

    return AddHabitRecordCommandResponse();
  }
}
