import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:domain/features/app_usages/app_usage_tag.dart';
import 'package:domain/features/app_usages/app_usage_time_record.dart';
import 'package:domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_tag.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/tags/tag_tag.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:domain/shared/utils/logger.dart';

/// Service for building bidirectional sync response DTOs.
/// Replaces 17 near-identical switch cases with a unified builder.
class SyncResponseBuilder {
  /// Creates a bidirectional response DTO for the given entity type.
  PaginatedSyncDataDto createBidirectionalResponseDto({
    required SyncDevice syncDevice,
    required PaginatedSyncData localData,
    required String entityType,
    int? currentServerPage,
    int? totalServerPages,
    bool? hasMoreServerPages,
  }) {
    DomainLogger.info(
        'Creating bidirectional response DTO for $entityType with ${localData.data.getTotalItemCount()} items');

    final baseParams = _BaseResponseParams(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: entityType,
      pageIndex: localData.pageIndex,
      pageSize: localData.pageSize,
      totalPages: localData.totalPages,
      totalItems: localData.totalItems,
      isLastPage: localData.isLastPage,
      currentServerPage: currentServerPage,
      totalServerPages: totalServerPages,
      hasMoreServerPages: hasMoreServerPages,
    );

    return _buildResponseForEntityType(baseParams, localData, entityType);
  }

  PaginatedSyncDataDto _buildResponseForEntityType(
    _BaseResponseParams params,
    PaginatedSyncData localData,
    String entityType,
  ) {
    switch (entityType) {
      case 'AppUsage':
        return _createDto(params, appUsagesSyncData: localData as PaginatedSyncData<AppUsage>?);
      case 'AppUsageTag':
        return _createDto(params, appUsageTagsSyncData: localData as PaginatedSyncData<AppUsageTag>?);
      case 'AppUsageTimeRecord':
        return _createDto(params, appUsageTimeRecordsSyncData: localData as PaginatedSyncData<AppUsageTimeRecord>?);
      case 'AppUsageTagRule':
        return _createDto(params, appUsageTagRulesSyncData: localData as PaginatedSyncData<AppUsageTagRule>?);
      case 'AppUsageIgnoreRule':
        return _createDto(params, appUsageIgnoreRulesSyncData: localData as PaginatedSyncData<AppUsageIgnoreRule>?);
      case 'Habit':
        return _createDto(params, habitsSyncData: localData as PaginatedSyncData<Habit>?);
      case 'HabitRecord':
        return _createDto(params, habitRecordsSyncData: localData as PaginatedSyncData<HabitRecord>?);
      case 'HabitTag':
        return _createDto(params, habitTagsSyncData: localData as PaginatedSyncData<HabitTag>?);
      case 'Tag':
        return _createDto(params, tagsSyncData: localData as PaginatedSyncData<Tag>?);
      case 'TagTag':
        return _createDto(params, tagTagsSyncData: localData as PaginatedSyncData<TagTag>?);
      case 'Task':
        return _createDto(params, tasksSyncData: localData as PaginatedSyncData<Task>?);
      case 'TaskTag':
        return _createDto(params, taskTagsSyncData: localData as PaginatedSyncData<TaskTag>?);
      case 'TaskTimeRecord':
        return _createDto(params, taskTimeRecordsSyncData: localData as PaginatedSyncData<TaskTimeRecord>?);
      case 'Setting':
        return _createDto(params, settingsSyncData: localData as PaginatedSyncData<Setting>?);
      case 'SyncDevice':
        return _createDto(params, syncDevicesSyncData: localData as PaginatedSyncData<SyncDevice>?);
      case 'Note':
        return _createDto(params, notesSyncData: localData as PaginatedSyncData<Note>?);
      case 'NoteTag':
        return _createDto(params, noteTagsSyncData: localData as PaginatedSyncData<NoteTag>?);
      default:
        DomainLogger.warning('Unknown entity type for bidirectional sync: $entityType');
        return _createDto(params);
    }
  }

  PaginatedSyncDataDto _createDto(
    _BaseResponseParams params, {
    PaginatedSyncData<AppUsage>? appUsagesSyncData,
    PaginatedSyncData<AppUsageTag>? appUsageTagsSyncData,
    PaginatedSyncData<AppUsageTimeRecord>? appUsageTimeRecordsSyncData,
    PaginatedSyncData<AppUsageTagRule>? appUsageTagRulesSyncData,
    PaginatedSyncData<AppUsageIgnoreRule>? appUsageIgnoreRulesSyncData,
    PaginatedSyncData<Habit>? habitsSyncData,
    PaginatedSyncData<HabitRecord>? habitRecordsSyncData,
    PaginatedSyncData<HabitTag>? habitTagsSyncData,
    PaginatedSyncData<Tag>? tagsSyncData,
    PaginatedSyncData<TagTag>? tagTagsSyncData,
    PaginatedSyncData<Task>? tasksSyncData,
    PaginatedSyncData<TaskTag>? taskTagsSyncData,
    PaginatedSyncData<TaskTimeRecord>? taskTimeRecordsSyncData,
    PaginatedSyncData<Setting>? settingsSyncData,
    PaginatedSyncData<SyncDevice>? syncDevicesSyncData,
    PaginatedSyncData<Note>? notesSyncData,
    PaginatedSyncData<NoteTag>? noteTagsSyncData,
  }) {
    return PaginatedSyncDataDto(
      appVersion: params.appVersion,
      syncDevice: params.syncDevice,
      isDebugMode: params.isDebugMode,
      entityType: params.entityType,
      pageIndex: params.pageIndex,
      pageSize: params.pageSize,
      totalPages: params.totalPages,
      totalItems: params.totalItems,
      isLastPage: params.isLastPage,
      currentServerPage: params.currentServerPage,
      totalServerPages: params.totalServerPages,
      hasMoreServerPages: params.hasMoreServerPages,
      appUsagesSyncData: appUsagesSyncData,
      appUsageTagsSyncData: appUsageTagsSyncData,
      appUsageTimeRecordsSyncData: appUsageTimeRecordsSyncData,
      appUsageTagRulesSyncData: appUsageTagRulesSyncData,
      appUsageIgnoreRulesSyncData: appUsageIgnoreRulesSyncData,
      habitsSyncData: habitsSyncData,
      habitRecordsSyncData: habitRecordsSyncData,
      habitTagsSyncData: habitTagsSyncData,
      tagsSyncData: tagsSyncData,
      tagTagsSyncData: tagTagsSyncData,
      tasksSyncData: tasksSyncData,
      taskTagsSyncData: taskTagsSyncData,
      taskTimeRecordsSyncData: taskTimeRecordsSyncData,
      settingsSyncData: settingsSyncData,
      syncDevicesSyncData: syncDevicesSyncData,
      notesSyncData: notesSyncData,
      noteTagsSyncData: noteTagsSyncData,
    );
  }
}

/// Internal helper class to hold common response parameters
class _BaseResponseParams {
  final String appVersion;
  final SyncDevice syncDevice;
  final bool isDebugMode;
  final String entityType;
  final int pageIndex;
  final int pageSize;
  final int totalPages;
  final int totalItems;
  final bool isLastPage;
  final int? currentServerPage;
  final int? totalServerPages;
  final bool? hasMoreServerPages;

  const _BaseResponseParams({
    required this.appVersion,
    required this.syncDevice,
    required this.isDebugMode,
    required this.entityType,
    required this.pageIndex,
    required this.pageSize,
    required this.totalPages,
    required this.totalItems,
    required this.isLastPage,
    this.currentServerPage,
    this.totalServerPages,
    this.hasMoreServerPages,
  });
}
