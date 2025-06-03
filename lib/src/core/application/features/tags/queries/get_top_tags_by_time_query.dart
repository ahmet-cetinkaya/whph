import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_data.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';

class GetTopTagsByTimeQuery implements IRequest<GetTopTagsByTimeQueryResponse> {
  final DateTime startDate;
  final DateTime endDate;
  final int? limit;
  final List<String>? filterByTags;
  final bool filterByIsArchived;
  final List<TagTimeCategory>? categories;

  GetTopTagsByTimeQuery({
    required DateTime startDate,
    required DateTime endDate,
    this.limit,
    this.filterByTags,
    this.filterByIsArchived = false,
    this.categories,
  })  : startDate = DateTimeHelper.toUtcDateTime(startDate),
        endDate = DateTimeHelper.toUtcDateTime(endDate);
}

class GetTopTagsByTimeQueryResponse {
  final List<TagTimeData> items;
  final int totalDuration;

  GetTopTagsByTimeQueryResponse({
    required this.items,
    required this.totalDuration,
  });
}

class GetTopTagsByTimeQueryHandler implements IRequestHandler<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse> {
  final IAppUsageTagRepository _appUsageTagRepository;
  final ITaskTagRepository _taskTagRepository;
  final IHabitTagsRepository _habitTagRepository;

  GetTopTagsByTimeQueryHandler({
    required IAppUsageTagRepository appUsageTagRepository,
    required ITaskTagRepository taskTagRepository,
    required IHabitTagsRepository habitTagRepository,
  })  : _appUsageTagRepository = appUsageTagRepository,
        _taskTagRepository = taskTagRepository,
        _habitTagRepository = habitTagRepository;

  @override
  Future<GetTopTagsByTimeQueryResponse> call(GetTopTagsByTimeQuery request) async {
    List<TagTimeData> allTagTimes = [];

    final categoriesToQuery = request.categories ?? [TagTimeCategory.all];

    if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.appUsage)) {
      final appUsageTagTimes = await _appUsageTagRepository.getTopTagsByDuration(
        request.startDate,
        request.endDate,
        limit: request.limit,
        filterByTags: request.filterByTags,
        filterByIsArchived: request.filterByIsArchived,
      );
      allTagTimes.addAll(appUsageTagTimes.map((tag) => TagTimeData(
            tagId: tag.tagId,
            tagName: tag.tagName,
            tagColor: tag.tagColor,
            duration: tag.duration,
            category: TagTimeCategory.appUsage,
          )));
    }

    if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.tasks)) {
      final taskTagTimes = await _taskTagRepository.getTopTagsByDuration(
        request.startDate,
        request.endDate,
        limit: request.limit,
        filterByTags: request.filterByTags,
        filterByIsArchived: request.filterByIsArchived,
      );
      allTagTimes.addAll(taskTagTimes.map((tag) => TagTimeData(
            tagId: tag.tagId,
            tagName: tag.tagName,
            tagColor: tag.tagColor,
            duration: tag.duration,
            category: TagTimeCategory.tasks,
          )));
    }

    if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.habits)) {
      final habitTagTimes = await _habitTagRepository.getTopTagsByDuration(
        request.startDate,
        request.endDate,
        limit: request.limit,
        filterByTags: request.filterByTags,
        filterByIsArchived: request.filterByIsArchived,
      );
      allTagTimes.addAll(habitTagTimes.map((tag) => TagTimeData(
            tagId: tag.tagId,
            tagName: tag.tagName,
            tagColor: tag.tagColor,
            duration: tag.duration,
            category: TagTimeCategory.habits,
          )));
    }

    // Sort by duration and take top limit
    allTagTimes.sort((a, b) => b.duration.compareTo(a.duration));
    if (request.limit != null && allTagTimes.length > request.limit!) {
      allTagTimes = allTagTimes.sublist(0, request.limit);
    }

    final totalDuration = allTagTimes.fold<int>(0, (sum, item) => sum + item.duration);

    return GetTopTagsByTimeQueryResponse(
      items: allTagTimes,
      totalDuration: totalDuration,
    );
  }
}
