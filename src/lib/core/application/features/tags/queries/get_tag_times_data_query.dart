import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:acore/acore.dart';

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
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTagsRepository _habitTagRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  GetTagTimesDataQueryHandler(
      {required IAppUsageTagRepository appUsageTagRepository,
      required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
      required ITaskRepository taskRepository,
      required ITaskTagRepository taskTagRepository,
      required ITaskTimeRecordRepository taskTimeRecordRepository,
      required IHabitRepository habitRepository,
      required IHabitRecordRepository habitRecordRepository,
      required IHabitTagsRepository habitTagRepository,
      required IHabitTimeRecordRepository habitTimeRecordRepository})
      : _appUsageTagRepository = appUsageTagRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTagRepository = habitTagRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<GetTagTimesDataQueryResponse> call(GetTagTimesDataQuery request) async {
    int time = 0;
    time += await _getAppUsageTagTimes(request);
    time += await _getTaskTagTimes(request);
    time += await _getHabitTagTimes(request);

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

  Future<int> _getHabitTagTimes(GetTagTimesDataQuery request) async {
    // Get habit tags within date range
    final habitTags = await _habitTagRepository.getAll(
        customWhereFilter: CustomWhereFilter("tag_id = ? AND deleted_date IS NULL", [request.tagId]));

    if (habitTags.isEmpty) return 0;

    // Get actual tracked time for all habits in a single batch query to avoid N+1 problem
    final habitIds = habitTags.map((habitTag) => habitTag.habitId).toList();
    final habitTimeMap = await _habitTimeRecordRepository.getTotalDurationsByHabitIds(
      habitIds,
      startDate: request.startDate,
      endDate: request.endDate,
    );

    // Get habits data for fallback to estimated time
    final habitFilter = CustomWhereFilter('id IN (${habitIds.map((_) => '?').join(',')})', habitIds);
    final habits = await _habitRepository.getAll(customWhereFilter: habitFilter);
    final habitMap = {for (var habit in habits) habit.id: habit};

    // Sum up all the times with fallback to estimated time
    int totalTime = 0;
    for (final habitId in habitIds) {
      final actualTime = habitTimeMap[habitId] ?? 0;

      if (actualTime > 0) {
        // Use actual tracked time
        totalTime += actualTime;
      } else {
        // Fallback to estimated time calculation
        final habit = habitMap[habitId];
        if (habit != null && habit.estimatedTime != null) {
          // Get habit records for the date range to calculate estimated time
          final records = await _habitRecordRepository.getListByHabitIdAndRangeDate(
            habitId,
            request.startDate,
            request.endDate,
            0,
            1000, // Large number to get all records
          );
          final recordCount = records.items.length;
          final estimatedTimeMinutes = habit.estimatedTime!;
          final estimatedDuration = recordCount * estimatedTimeMinutes * 60; // Convert to seconds
          totalTime += estimatedDuration;
        }
      }
    }

    return totalTime;
  }
}
