import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
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

  AddHabitRecordCommandHandler({required IHabitRecordRepository habitRecordRepository})
      : _habitRecordRepository = habitRecordRepository;

  @override
  Future<AddHabitRecordCommandResponse> call(AddHabitRecordCommand request) async {
    final now = DateTime.now().toUtc();
    HabitRecord habitRecord = HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: now,
      habitId: request.habitId,
      occurredAt: request.occurredAt, // This is now guaranteed to be non-null from the command constructor
    );
    await _habitRecordRepository.add(habitRecord);

    return AddHabitRecordCommandResponse();
  }
}
