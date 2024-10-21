import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/domain/features/habits/habit_record.dart';

class AddHabitRecordCommand implements IRequest<AddHabitRecordCommandResponse> {
  final String habitId;
  final DateTime date;

  AddHabitRecordCommand({
    required this.habitId,
    required this.date,
  });
}

class AddHabitRecordCommandResponse {}

class AddHabitRecordCommandHandler implements IRequestHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;

  AddHabitRecordCommandHandler({required IHabitRecordRepository habitRecordRepository})
      : _habitRecordRepository = habitRecordRepository;

  @override
  Future<AddHabitRecordCommandResponse> call(AddHabitRecordCommand request) async {
    HabitRecord habitRecord = HabitRecord(
      id: nanoid(),
      createdDate: DateTime(0),
      habitId: request.habitId,
      date: request.date,
    );
    await _habitRecordRepository.add(habitRecord);

    return AddHabitRecordCommandResponse();
  }
}
