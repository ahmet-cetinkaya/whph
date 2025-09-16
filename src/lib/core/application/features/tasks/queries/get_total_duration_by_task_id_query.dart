import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';

class GetTotalDurationByTaskIdQuery implements IRequest<GetTotalDurationByTaskIdQueryResponse> {
  final String taskId;
  final DateTime? startDate;
  final DateTime? endDate;

  GetTotalDurationByTaskIdQuery({
    required this.taskId,
    this.startDate,
    this.endDate,
  });
}

class GetTotalDurationByTaskIdQueryResponse {
  final int totalDuration;

  GetTotalDurationByTaskIdQueryResponse({
    required this.totalDuration,
  });
}

class GetTotalDurationByTaskIdQueryHandler
    implements IRequestHandler<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse> {
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  GetTotalDurationByTaskIdQueryHandler({
    required ITaskTimeRecordRepository taskTimeRecordRepository,
  }) : _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<GetTotalDurationByTaskIdQueryResponse> call(GetTotalDurationByTaskIdQuery request) async {
    final totalDuration = await _taskTimeRecordRepository.getTotalDurationByTaskId(
      request.taskId,
      startDate: request.startDate,
      endDate: request.endDate,
    );

    return GetTotalDurationByTaskIdQueryResponse(totalDuration: totalDuration);
  }
}
