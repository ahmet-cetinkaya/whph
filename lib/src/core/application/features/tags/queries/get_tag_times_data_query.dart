import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/corePackages/acore/repository/models/custom_where_filter.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';

class GetTagTimesDataQuery implements IRequest<GetTagTimesDataQueryResponse> {
  final String tagId;
  final DateTime startDate;
  final DateTime endDate;

  GetTagTimesDataQuery({
    required this.tagId,
    required DateTime startDate,
    required DateTime endDate,
  })  : startDate = DateTimeHelper.toUtcDateTime(startDate),
        endDate = DateTimeHelper.toUtcDateTime(endDate);
}

class GetTagTimesDataQueryResponse {
  final String tagId;
  final int time;

  GetTagTimesDataQueryResponse({required this.tagId, required this.time});
}

class GetTagTimesDataQueryHandler implements IRequestHandler<GetTagTimesDataQuery, GetTagTimesDataQueryResponse> {
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  GetTagTimesDataQueryHandler(
      {required IAppUsageTagRepository appUsageTagRepository,
      required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
      required ITaskRepository taskRepository,
      required ITaskTagRepository taskTagRepository,
      required ITaskTimeRecordRepository taskTimeRecordRepository})
      : _appUsageTagRepository = appUsageTagRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<GetTagTimesDataQueryResponse> call(GetTagTimesDataQuery request) async {
    int time = 0;
    time += await _getAppUsageTagTimes(request);
    time += await _getTaskTagTimes(request);

    return GetTagTimesDataQueryResponse(tagId: request.tagId, time: time);
  }

  Future<int> _getAppUsageTagTimes(GetTagTimesDataQuery request) async {
    // Get all app usages with this tag
    final appUsageTags = await _appUsageTagRepository.getAll(
        customWhereFilter: CustomWhereFilter("tag_id = ? AND deleted_date IS NULL", [request.tagId]));

    if (appUsageTags.isEmpty) return 0;

    // Get total duration from time records for these app usages
    final appUsageIds = appUsageTags.map((e) => e.appUsageId).toList();
    final durations = await _appUsageTimeRecordRepository.getAppUsageDurations(
      appUsageIds: appUsageIds,
      startDate: request.startDate,
      endDate: request.endDate,
    );

    final total = durations.values.fold(0, (sum, duration) => sum + duration);
    return total;
  }

  Future<int> _getTaskTagTimes(GetTagTimesDataQuery request) async {
    // Get task tags within date range
    final taskTags = await _taskTagRepository.getAll(
        customWhereFilter: CustomWhereFilter("tag_id = ? AND deleted_date IS NULL", [request.tagId]));

    if (taskTags.isEmpty) return 0;

    int totalTime = 0;
    for (final taskTag in taskTags) {
      final taskTime = await _taskTimeRecordRepository.getTotalDurationByTaskId(
        taskTag.taskId,
        startDate: request.startDate,
        endDate: request.endDate,
      );
      totalTime += taskTime;
    }

    return totalTime;
  }
}
