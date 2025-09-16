import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:acore/acore.dart';

class SaveTaskTimeRecordCommand implements IRequest<SaveTaskTimeRecordCommandResponse> {
  final String taskId;
  final int duration;
  final DateTime? targetDate;

  SaveTaskTimeRecordCommand({
    required this.taskId,
    required this.duration,
    this.targetDate,
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
    final targetDate = request.targetDate ?? DateTime.now().toUtc();
    final startOfDay = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get existing records for the target date - use DateTime objects directly like habits do
    final existingRecordsFilter = CustomWhereFilter(
      'task_id = ? AND created_date >= ? AND created_date < ?',
      [request.taskId, startOfDay, endOfDay],
    );
    final existingRecords = await _taskTimeRecordRepository.getAll(customWhereFilter: existingRecordsFilter);

    // Delete existing records for the day
    for (final record in existingRecords) {
      await _taskTimeRecordRepository.delete(record);
    }

    // Add new record if duration > 0
    if (request.duration > 0) {
      // Use the start of the hour for the target date
      final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);

      final taskTimeRecord = TaskTimeRecord(
        id: KeyHelper.generateStringId(),
        taskId: request.taskId,
        duration: request.duration,
        createdDate: startOfHour,
      );

      await _taskTimeRecordRepository.add(taskTimeRecord);
      return SaveTaskTimeRecordCommandResponse(id: taskTimeRecord.id);
    }

    return SaveTaskTimeRecordCommandResponse(id: KeyHelper.generateStringId());
  }
}
