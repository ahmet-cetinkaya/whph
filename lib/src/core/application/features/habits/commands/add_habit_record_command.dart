import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';

class AddHabitRecordCommand implements IRequest<AddHabitRecordCommandResponse> {
  final String habitId;
  final DateTime date;

  AddHabitRecordCommand({
    required this.habitId,
    required DateTime date,
  }) : date = DateTimeHelper.toUtcDateTime(date);
}

class AddHabitRecordCommandResponse {}

class AddHabitRecordCommandHandler implements IRequestHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;

  AddHabitRecordCommandHandler({required IHabitRecordRepository habitRecordRepository})
      : _habitRecordRepository = habitRecordRepository;

  @override
  Future<AddHabitRecordCommandResponse> call(AddHabitRecordCommand request) async {
    HabitRecord habitRecord = HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      habitId: request.habitId,
      date: request.date,
    );
    await _habitRecordRepository.add(habitRecord);

    return AddHabitRecordCommandResponse();
  }
}
