import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:domain/shared/utils/logger.dart';

/// Builds PaginatedSyncDataDto for different entity types
class SyncDtoBuilder {
  /// Builds DTO for the given entity type with appropriate sync data
  PaginatedSyncDataDto buildDto({
    required SyncDevice syncDevice,
    required PaginatedSyncData paginatedData,
    required String entityType,
    SyncProgress? progress,
  }) {
    DomainLogger.debug('Creating DTO for $entityType with isDebugMode: $kDebugMode');

    switch (entityType) {
      case 'AppUsage':
        return _buildAppUsageDto(syncDevice, paginatedData, progress);

      case 'Task':
        return _buildTaskDto(syncDevice, paginatedData as PaginatedSyncData<Task>, progress);

      case 'Habit':
        return _buildHabitDto(syncDevice, paginatedData as PaginatedSyncData<Habit>, progress);

      case 'HabitRecord':
        return _buildHabitRecordDto(syncDevice, paginatedData, progress);

      case 'HabitTag':
        return _buildHabitTagDto(syncDevice, paginatedData, progress);

      case 'SyncDevice':
        return _buildSyncDeviceDto(syncDevice, paginatedData, progress);

      default:
        return _buildGenericDto(syncDevice, paginatedData, entityType, progress);
    }
  }

  PaginatedSyncDataDto _buildAppUsageDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    SyncProgress? progress,
  ) {
    final appUsagesData = paginatedData.data.getTotalItemCount() > 0 ? paginatedData as dynamic : null;
    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'AppUsage',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      appUsagesSyncData: appUsagesData,
    );
  }

  PaginatedSyncDataDto _buildTaskDto(
    SyncDevice syncDevice,
    PaginatedSyncData<Task> paginatedData,
    SyncProgress? progress,
  ) {
    final itemCount = paginatedData.data.getTotalItemCount();
    DomainLogger.debug('SERVICE Task DTO - ENTRY: itemCount=$itemCount, totalItems=${paginatedData.totalItems}');
    DomainLogger.debug(
        'SERVICE Task DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}');

    final tasksData = itemCount > 0 ? paginatedData : null;
    DomainLogger.debug('SERVICE Task DTO - tasksData is null: ${tasksData == null}');

    final dto = PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'Task',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      tasksSyncData: tasksData,
    );

    DomainLogger.debug('Final Task DTO - tasksSyncData is null: ${dto.tasksSyncData == null}');
    return dto;
  }

  PaginatedSyncDataDto _buildHabitDto(
    SyncDevice syncDevice,
    PaginatedSyncData<Habit> paginatedData,
    SyncProgress? progress,
  ) {
    final itemCount = paginatedData.data.getTotalItemCount();
    DomainLogger.debug('Habit DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
    DomainLogger.debug(
        'Habit DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

    final habitsData = itemCount > 0 ? paginatedData : null;
    DomainLogger.debug('Habit DTO - habitsData is null: ${habitsData == null}');

    if (habitsData != null) {
      DomainLogger.debug(
          'Habit DTO - sample habit IDs: ${habitsData.data.createSync.take(3).map((h) => h.id).toList()}');
    }

    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'Habit',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      habitsSyncData: habitsData,
    );
  }

  PaginatedSyncDataDto _buildHabitRecordDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    SyncProgress? progress,
  ) {
    final itemCount = paginatedData.data.getTotalItemCount();
    DomainLogger.debug('HabitRecord DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
    DomainLogger.debug(
        'HabitRecord DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

    final habitRecordsData = itemCount > 0 ? paginatedData as dynamic : null;
    DomainLogger.debug('HabitRecord DTO - habitRecordsData is null: ${habitRecordsData == null}');

    if (habitRecordsData != null) {
      DomainLogger.debug(
          'HabitRecord DTO - sample record IDs: ${habitRecordsData.data.createSync.take(3).map((r) => r.id).toList()}');
    }

    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'HabitRecord',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      habitRecordsSyncData: habitRecordsData,
    );
  }

  PaginatedSyncDataDto _buildHabitTagDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    SyncProgress? progress,
  ) {
    final itemCount = paginatedData.data.getTotalItemCount();
    DomainLogger.debug('HabitTag DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
    DomainLogger.debug(
        'HabitTag DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

    final habitTagsData = itemCount > 0 ? paginatedData as dynamic : null;
    DomainLogger.debug('HabitTag DTO - habitTagsData is null: ${habitTagsData == null}');

    if (habitTagsData != null) {
      DomainLogger.debug(
          'HabitTag DTO - sample tag IDs: ${habitTagsData.data.createSync.take(3).map((t) => t.id).toList()}');
    }

    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'HabitTag',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      habitTagsSyncData: habitTagsData,
    );
  }

  PaginatedSyncDataDto _buildSyncDeviceDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    SyncProgress? progress,
  ) {
    final syncDeviceData = paginatedData.data.getTotalItemCount() > 0 ? paginatedData as dynamic : null;
    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: 'SyncDevice',
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      syncDevicesSyncData: syncDeviceData,
    );
  }

  PaginatedSyncDataDto _buildGenericDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    String entityType,
    SyncProgress? progress,
  ) {
    DomainLogger.debug('Default case triggered for entity type: $entityType');

    if (entityType.contains('Habit')) {
      DomainLogger.warning(
          'Habit-related entity $entityType fell through to default case - this may indicate missing explicit handling');
    }

    final hasData = paginatedData.data.getTotalItemCount() > 0;
    DomainLogger.debug('Default case - hasData: $hasData, itemCount: ${paginatedData.data.getTotalItemCount()}');

    final syncDataDynamic = hasData ? paginatedData as dynamic : null;
    DomainLogger.debug('Default case - syncDataDynamic is null: ${syncDataDynamic == null}');

    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: kDebugMode,
      entityType: entityType,
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      // Set the appropriate field based on entity type with dynamic casting
      appUsagesSyncData: entityType == 'AppUsage' ? syncDataDynamic : null,
      appUsageTagsSyncData: entityType == 'AppUsageTag' ? syncDataDynamic : null,
      appUsageTimeRecordsSyncData: entityType == 'AppUsageTimeRecord' ? syncDataDynamic : null,
      appUsageTagRulesSyncData: entityType == 'AppUsageTagRule' ? syncDataDynamic : null,
      appUsageIgnoreRulesSyncData: entityType == 'AppUsageIgnoreRule' ? syncDataDynamic : null,
      habitsSyncData: entityType == 'Habit' ? syncDataDynamic : null,
      habitRecordsSyncData: entityType == 'HabitRecord' ? syncDataDynamic : null,
      habitTagsSyncData: entityType == 'HabitTag' ? syncDataDynamic : null,
      tagsSyncData: entityType == 'Tag' ? syncDataDynamic : null,
      tagTagsSyncData: entityType == 'TagTag' ? syncDataDynamic : null,
      tasksSyncData: entityType == 'Task' ? syncDataDynamic : null,
      taskTagsSyncData: entityType == 'TaskTag' ? syncDataDynamic : null,
      taskTimeRecordsSyncData: entityType == 'TaskTimeRecord' ? syncDataDynamic : null,
      settingsSyncData: entityType == 'Setting' ? syncDataDynamic : null,
      syncDevicesSyncData: entityType == 'SyncDevice' ? syncDataDynamic : null,
      notesSyncData: entityType == 'Note' ? syncDataDynamic : null,
      noteTagsSyncData: entityType == 'NoteTag' ? syncDataDynamic : null,
    );
  }
}
