import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';

class AddTaskTimeRecordCommand
    implements IRequest<AddTaskTimeRecordCommandResponse> {
  final String taskId;
  final int duration;
  final DateTime? customDateTime;

  AddTaskTimeRecordCommand({
    required this.taskId,
    required this.duration,
    this.customDateTime,
  });
}

class AddTaskTimeRecordCommandResponse {
  final String id;

  AddTaskTimeRecordCommandResponse({
    required this.id,
  });
}

class AddTaskTimeRecordCommandHandler
    implements
        IRequestHandler<AddTaskTimeRecordCommand,
            AddTaskTimeRecordCommandResponse> {
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskEvents? _taskEvents;
  final IDeviceIdService _deviceIds;

  AddTaskTimeRecordCommandHandler({
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required IDeviceIdService deviceIds,
    ITaskEvents? taskEvents,
  })  : _taskTimeRecordRepository = taskTimeRecordRepository,
        _deviceIds = deviceIds,
        _taskEvents = taskEvents;

  @override
  Future<AddTaskTimeRecordCommandResponse> call(
      AddTaskTimeRecordCommand request) async {
    final targetDate = request.customDateTime ?? DateTime.now().toUtc();

    final record = await TaskTimeRecordService.addDurationToTaskTimeRecord(
      repository: _taskTimeRecordRepository,
      taskId: request.taskId,
      targetDate: targetDate,
      deviceId: await _deviceIds.getDeviceId(),
      durationToAdd: request.duration,
    );
    _taskEvents?.notifyTaskTimeRecordUpdated(request.taskId);

    return AddTaskTimeRecordCommandResponse(id: record.id);
  }
}
