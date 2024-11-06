import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/habits/habit_record.dart';

class DeleteHabitRecordCommand implements IRequest<DeleteHabitRecordCommandResponse> {
  final String id;

  DeleteHabitRecordCommand({required this.id});
}

class DeleteHabitRecordCommandResponse {}

class DeleteHabitRecordCommandHandler
    implements IRequestHandler<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;

  DeleteHabitRecordCommandHandler({required IHabitRecordRepository habitRecordRepository})
      : _habitRecordRepository = habitRecordRepository;

  @override
  Future<DeleteHabitRecordCommandResponse> call(DeleteHabitRecordCommand request) async {
    HabitRecord? habitRecord = await _habitRecordRepository.getById(request.id);
    if (habitRecord == null) {
      throw BusinessException('HabitRecord with id ${request.id} not found');
    }

    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }
}
