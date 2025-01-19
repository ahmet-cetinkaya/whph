import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';

class SaveTaskTimeRecordCommand implements IRequest<SaveTaskTimeRecordCommandResponse> {
  final String taskId;
  final int duration;

  SaveTaskTimeRecordCommand({
    required this.taskId,
    required this.duration,
  });
}

class SaveTaskTimeRecordCommandResponse {
  final String id;

  SaveTaskTimeRecordCommandResponse({
    required this.id,
  });
}

class SaveTaskTimeRecordCommandHandler
    implements IRequestHandler<SaveTaskTimeRecordCommand, SaveTaskTimeRecordCommandResponse> {
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  SaveTaskTimeRecordCommandHandler({
    required ITaskTimeRecordRepository taskTimeRecordRepository,
  }) : _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<SaveTaskTimeRecordCommandResponse> call(SaveTaskTimeRecordCommand request) async {
    final now = DateTime.now();
    final startOfHour = DateTime(now.year, now.month, now.day, now.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));

    final filter = CustomWhereFilter(
        'task_id = ? AND created_date >= ? AND created_date < ?', [request.taskId, startOfHour, endOfHour]);

    final existingRecord = await _taskTimeRecordRepository.getFirst(filter);

    if (existingRecord != null) {
      existingRecord.duration += request.duration;
      await _taskTimeRecordRepository.update(existingRecord);
      return SaveTaskTimeRecordCommandResponse(id: existingRecord.id);
    }

    var taskTimeRecord = TaskTimeRecord(
      id: nanoid(),
      taskId: request.taskId,
      duration: request.duration,
      createdDate: now,
    );

    await _taskTimeRecordRepository.add(taskTimeRecord);
    return SaveTaskTimeRecordCommandResponse(id: taskTimeRecord.id);
  }
}
