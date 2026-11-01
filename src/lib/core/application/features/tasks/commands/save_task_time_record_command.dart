import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';

class SaveTaskTimeRecordCommand
    implements IRequest<SaveTaskTimeRecordCommandResponse> {
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
    implements
        IRequestHandler<SaveTaskTimeRecordCommand,
            SaveTaskTimeRecordCommandResponse> {
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskEvents? _taskEvents;
  final IDeviceIdService _deviceIds;

  SaveTaskTimeRecordCommandHandler({
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required IDeviceIdService deviceIds,
    ITaskEvents? taskEvents,
  })  : _taskTimeRecordRepository = taskTimeRecordRepository,
        _deviceIds = deviceIds,
        _taskEvents = taskEvents;

  @override
  Future<SaveTaskTimeRecordCommandResponse> call(
      SaveTaskTimeRecordCommand request) async {
    final targetDate = request.targetDate ?? DateTime.now().toUtc();
    final (startOfDay, _) =
        TaskTimeRecordService.createDayBoundaries(targetDate);
    final deviceId = await _deviceIds.getDeviceId();

    // D12 day-level set-total: no soft deletes; the own bucket absorbs the
    // delta against other devices' live buckets of the day and the own day's
    // other hours are zeroed. Target 0 uses the same formula.
    final record = await TaskTimeRecordService.setTotalDurationForDay(
      repository: _taskTimeRecordRepository,
      taskId: request.taskId,
      dayStart: startOfDay,
      targetHour: targetDate,
      deviceId: deviceId,
      totalDuration: request.duration,
    );

    _taskEvents?.notifyTaskTimeRecordUpdated(request.taskId);
    return SaveTaskTimeRecordCommandResponse(
        id: request.duration > 0 ? record.id : KeyHelper.generateStringId());
  }
}
