import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/corePackages/acore/repository/models/custom_where_filter.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';

class GetElementsByTimeQuery implements IRequest<GetElementsByTimeQueryResponse> {
  final DateTime startDate;
  final DateTime endDate;
  final int? limit;
  final List<String>? filterByTags;
  final bool filterByIsArchived;
  final List<TagTimeCategory>? categories;

  GetElementsByTimeQuery({
    required DateTime startDate,
    required DateTime endDate,
    this.limit,
    this.filterByTags,
    this.filterByIsArchived = false,
    this.categories,
  })  : startDate = DateTimeHelper.toUtcDateTime(startDate),
        endDate = DateTimeHelper.toUtcDateTime(endDate);
}

class ElementTimeData {
  final String id;
  final String name;
  final int duration;
  final TagTimeCategory category;
  final String? color;
  final String? tagId;
  final String? tagName;
  final String? tagColor;

  const ElementTimeData({
    required this.id,
    required this.name,
    required this.duration,
    required this.category,
    this.color,
    this.tagId,
    this.tagName,
    this.tagColor,
  });
}

class GetElementsByTimeQueryResponse {
  final List<ElementTimeData> items;
  final int totalDuration;

  GetElementsByTimeQueryResponse({
    required this.items,
    required this.totalDuration,
  });
}

class GetElementsByTimeQueryHandler implements IRequestHandler<GetElementsByTimeQuery, GetElementsByTimeQueryResponse> {
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTagsRepository _habitTagRepository;
  final ITagRepository _tagRepository;

  GetElementsByTimeQueryHandler({
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
    required IAppUsageTagRepository appUsageTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required ITaskRepository taskRepository,
    required ITaskTagRepository taskTagRepository,
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTagsRepository habitTagRepository,
    required ITagRepository tagRepository,
  })  : _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository,
        _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTagRepository = habitTagRepository,
        _tagRepository = tagRepository;

  @override
  Future<GetElementsByTimeQueryResponse> call(GetElementsByTimeQuery request) async {
    List<ElementTimeData> allElementTimes = [];
    final categoriesToQuery = request.categories ?? [TagTimeCategory.all];

    try {
      // Get app usages with time records in the date range
      if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.appUsage)) {
        final appUsageTimes = await _getAppUsageTimes(request);
        allElementTimes.addAll(appUsageTimes);
      }

      // Get tasks with time records in the date range
      if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.tasks)) {
        final taskTimes = await _getTaskTimes(request);
        allElementTimes.addAll(taskTimes);
      }

      // Get habits with records in the date range
      if (categoriesToQuery.contains(TagTimeCategory.all) || categoriesToQuery.contains(TagTimeCategory.habits)) {
        final habitTimes = await _getHabitTimes(request);
        allElementTimes.addAll(habitTimes);
      }

      // Sort by duration and take top limit
      allElementTimes.sort((a, b) => b.duration.compareTo(a.duration));
      if (request.limit != null && allElementTimes.length > request.limit!) {
        allElementTimes = allElementTimes.sublist(0, request.limit!);
      }

      final totalDuration = allElementTimes.fold<int>(0, (sum, item) => sum + item.duration);

      return GetElementsByTimeQueryResponse(
        items: allElementTimes,
        totalDuration: totalDuration,
      );
    } catch (e) {
      debugPrint('Error getting element times: $e');
      return GetElementsByTimeQueryResponse(
        items: [],
        totalDuration: 0,
      );
    }
  }

  Future<List<ElementTimeData>> _getAppUsageTimes(GetElementsByTimeQuery request) async {
    try {
      final appUsages = await _appUsageTimeRecordRepository.getTopAppUsagesWithDetails(
        pageIndex: 0,
        pageSize: 100, // Get a large number to ensure we get all
        filterByTags: request.filterByTags,
        startDate: request.startDate,
        endDate: request.endDate,
      );

      // Convert to ElementTimeData
      final elementTimes = <ElementTimeData>[];

      for (final appUsage in appUsages.items) {
        // Skip app usages that don't have the requested tags
        if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
          bool hasMatchingTag = false;

          // Check if app usage has any of the requested tags
          for (final tagId in request.filterByTags!) {
            if (await _appUsageTagRepository.anyByAppUsageIdAndTagId(appUsage.id, tagId)) {
              hasMatchingTag = true;
              break;
            }
          }

          if (!hasMatchingTag) continue;
        }

        // Get the first tag for this app usage (if any)
        String? tagId;
        String? tagName;
        String? tagColor;

        // Get tags for this app usage
        final appUsageTags = await _appUsageTagRepository.getListByAppUsageId(
          appUsage.id,
          0, // pageIndex
          1, // pageSize - just get the first tag
        );

        // If there are any tags, use the first one
        if (appUsageTags.items.isNotEmpty) {
          final appUsageTag = appUsageTags.items.first;
          tagId = appUsageTag.tagId;

          // Get tag details
          final tag = await _tagRepository.getById(tagId);
          if (tag != null) {
            tagName = tag.name;
            tagColor = tag.color;
          }
        }

        elementTimes.add(
          ElementTimeData(
            id: appUsage.id,
            name: appUsage.displayName ?? appUsage.name,
            duration: appUsage.duration,
            category: TagTimeCategory.appUsage,
            color: appUsage.color,
            tagId: tagId,
            tagName: tagName,
            tagColor: tagColor,
          ),
        );
      }

      return elementTimes;
    } catch (e) {
      debugPrint('Error getting app usage times: $e');
      return [];
    }
  }

  Future<List<ElementTimeData>> _getTaskTimes(GetElementsByTimeQuery request) async {
    try {
      // Get all tasks
      final filter = CustomWhereFilter(
        'deleted_date IS NULL',
        [],
      );
      final tasks = await _taskRepository.getAll(customWhereFilter: filter);

      // Get time records for each task
      final elementTimes = <ElementTimeData>[];
      for (final task in tasks) {
        // Skip tasks that don't have the requested tags
        if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
          bool hasMatchingTag = false;

          // Check if task has any of the requested tags
          for (final tagId in request.filterByTags!) {
            if (await _taskTagRepository.anyByTaskIdAndTagId(task.id, tagId)) {
              hasMatchingTag = true;
              break;
            }
          }

          if (!hasMatchingTag) continue;
        }

        // Get total duration for this task in the date range
        final duration = await _taskTimeRecordRepository.getTotalDurationByTaskId(
          task.id,
          startDate: request.startDate,
          endDate: request.endDate,
        );

        // Only include tasks with time records
        if (duration > 0) {
          // Get the first tag for this task (if any)
          String? tagId;
          String? tagName;
          String? tagColor;

          // Get tags for this task
          final taskTags = await _taskTagRepository.getList(
            0, // pageIndex
            1, // pageSize - just get the first tag
            customWhereFilter: CustomWhereFilter("task_id = ?", [task.id]),
          );

          // If there are any tags, use the first one
          if (taskTags.items.isNotEmpty) {
            final taskTag = taskTags.items.first;
            tagId = taskTag.tagId;

            // Get tag details
            final tag = await _tagRepository.getById(tagId);
            if (tag != null) {
              tagName = tag.name;
              tagColor = tag.color;
            }
          }

          elementTimes.add(
            ElementTimeData(
              id: task.id,
              name: task.title,
              duration: duration,
              category: TagTimeCategory.tasks,
              tagId: tagId,
              tagName: tagName,
              tagColor: tagColor,
            ),
          );
        }
      }

      return elementTimes;
    } catch (e) {
      debugPrint('Error getting task times: $e');
      return [];
    }
  }

  Future<List<ElementTimeData>> _getHabitTimes(GetElementsByTimeQuery request) async {
    try {
      // Get all habits
      final filter = CustomWhereFilter(
        'deleted_date IS NULL',
        [],
      );
      final habits = await _habitRepository.getAll(customWhereFilter: filter);

      // Get records for each habit
      final elementTimes = <ElementTimeData>[];
      for (final habit in habits) {
        // Skip habits that don't have the requested tags
        if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
          bool hasMatchingTag = false;

          // Check if habit has any of the requested tags
          for (final tagId in request.filterByTags!) {
            if (await _habitTagRepository.anyByHabitIdAndTagId(habit.id, tagId)) {
              hasMatchingTag = true;
              break;
            }
          }

          if (!hasMatchingTag) continue;
        }

        // Get records for this habit in the date range
        final records = await _habitRecordRepository.getListByHabitIdAndRangeDate(
          habit.id,
          request.startDate,
          request.endDate,
          0,
          1000, // Large number to get all records
        );

        // Calculate duration based on habit records and estimated time
        final recordCount = records.items.length;
        final estimatedTimeMinutes = habit.estimatedTime ?? 0;
        final duration = recordCount * estimatedTimeMinutes * 60; // Convert to seconds

        // Only include habits with records
        if (duration > 0) {
          // Get the first tag for this habit (if any)
          String? tagId;
          String? tagName;
          String? tagColor;

          // Get tags for this habit
          final habitTags = await _habitTagRepository.getListByHabitId(
            habit.id,
            0, // pageIndex
            1, // pageSize - just get the first tag
          );

          // If there are any tags, use the first one
          if (habitTags.items.isNotEmpty) {
            final habitTag = habitTags.items.first;
            tagId = habitTag.tagId;

            // Get tag details
            final tag = await _tagRepository.getById(tagId);
            if (tag != null) {
              tagName = tag.name;
              tagColor = tag.color;
            }
          }

          elementTimes.add(
            ElementTimeData(
              id: habit.id,
              name: habit.name,
              duration: duration,
              category: TagTimeCategory.habits,
              tagId: tagId,
              tagName: tagName,
              tagColor: tagColor,
            ),
          );
        }
      }

      return elementTimes;
    } catch (e) {
      debugPrint('Error getting habit times: $e');
      return [];
    }
  }
}
