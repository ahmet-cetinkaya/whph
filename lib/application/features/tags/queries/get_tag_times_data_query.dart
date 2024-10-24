import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

class GetTagTimesDataQuery implements IRequest<GetTagTimesDataQueryResponse> {
  final String tagId;

  GetTagTimesDataQuery({required this.tagId});
}

class GetTagTimesDataQueryResponse {
  final String tagId;
  final int time;

  GetTagTimesDataQueryResponse({required this.tagId, required this.time});
}

class GetTagTimesDataQueryHandler implements IRequestHandler<GetTagTimesDataQuery, GetTagTimesDataQueryResponse> {
  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTagRepository _appUsageTagRepository;

  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;

  GetTagTimesDataQueryHandler(
      {required IAppUsageRepository appUsageRepository,
      required IAppUsageTagRepository appUsageTagRepository,
      required ITaskRepository taskRepository,
      required ITaskTagRepository taskTagRepository})
      : _appUsageRepository = appUsageRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository;

  @override
  Future<GetTagTimesDataQueryResponse> call(GetTagTimesDataQuery request) async {
    int time = 0;
    time += await _getAppUsageTagTimes(request);
    time += await _getTaskTagTimes(request);

    return GetTagTimesDataQueryResponse(tagId: request.tagId, time: time);
  }

  Future<int> _getAppUsageTagTimes(GetTagTimesDataQuery request) async {
    int time = 0;

    PaginatedList<AppUsageTag>? appUsageTags;
    do {
      appUsageTags = await _appUsageTagRepository.getList((appUsageTags?.pageIndex ?? -1) + 1, 100,
          customWhereFilter: CustomWhereFilter("tag_id = ?", [request.tagId]));

      for (final appUsage in appUsageTags.items) {
        AppUsage? appUsageData = await _appUsageRepository.getById(appUsage.appUsageId);
        if (appUsageData == null) continue;

        time += appUsageData.duration;
      }
    } while (appUsageTags.hasNext);

    return time;
  }

  Future<int> _getTaskTagTimes(GetTagTimesDataQuery request) async {
    int time = 0;

    PaginatedList<TaskTag>? taskTags;
    do {
      taskTags = await _taskTagRepository.getList((taskTags?.pageIndex ?? -1) + 1, 100,
          customWhereFilter: CustomWhereFilter("tag_id = ?", [request.tagId]));

      for (final taskTag in taskTags.items) {
        Task? task = await _taskRepository.getById(taskTag.taskId);
        if (task == null) continue;

        if (task.elapsedTime != null) time += task.elapsedTime!;
      }
    } while (taskTags.hasNext);

    return time;
  }
}
