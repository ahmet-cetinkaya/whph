import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/src/core/domain/features/tasks/task_time_record.dart';
import 'package:acore/acore.dart';

class AddTaskTimeRecordCommand implements IRequest<AddTaskTimeRecordCommandResponse> {
  final String taskId;
  final int duration;

  AddTaskTimeRecordCommand({
    required this.taskId,
    required this.duration,
  });
}

class AddTaskTimeRecordCommandResponse {
  final String id;

  AddTaskTimeRecordCommandResponse({
    required this.id,
  });
}

class AddTaskTimeRecordCommandHandler
    implements IRequestHandler<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse> {
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  AddTaskTimeRecordCommandHandler({
    required ITaskTimeRecordRepository taskTimeRecordRepository,
  }) : _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<AddTaskTimeRecordCommandResponse> call(AddTaskTimeRecordCommand request) async {
    final now = DateTime.now().toUtc();
    final startOfHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));

    final filter = CustomWhereFilter(
        'task_id = ? AND created_date >= ? AND created_date < ?', [request.taskId, startOfHour, endOfHour]);

    final existingRecord = await _taskTimeRecordRepository.getFirst(filter);

    if (existingRecord != null) {
      existingRecord.duration += request.duration;
      await _taskTimeRecordRepository.update(existingRecord);
      return AddTaskTimeRecordCommandResponse(id: existingRecord.id);
    }

    final taskTimeRecord = TaskTimeRecord(
      id: KeyHelper.generateStringId(),
      taskId: request.taskId,
      duration: request.duration,
      createdDate: now,
    );

    await _taskTimeRecordRepository.add(taskTimeRecord);
    return AddTaskTimeRecordCommandResponse(id: taskTimeRecord.id);
  }
}
