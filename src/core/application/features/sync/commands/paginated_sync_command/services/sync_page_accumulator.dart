import 'package:acore/acore.dart';
import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:application/features/sync/models/sync_data.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:domain/features/app_usages/app_usage_tag.dart';
import 'package:domain/features/app_usages/app_usage_time_record.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_tag.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:domain/shared/utils/logger.dart';

/// Service for accumulating multiple pages of sync data into a single DTO.
/// Replaces 13 entity-specific accumulator methods with a generic solution.
class SyncPageAccumulator {
  /// Accumulates multiple pages of the same entity type into a single DTO.
  /// If only one page is provided, returns it directly.
  PaginatedSyncDataDto accumulatePages(
    List<PaginatedSyncDataDto> responseDtos,
    String entityType,
  ) {
    if (responseDtos.isEmpty) {
      throw ArgumentError('Cannot accumulate empty list of response DTOs');
    }

    if (responseDtos.length == 1) {
      return responseDtos.first;
    }

    DomainLogger.info('Accumulating ${responseDtos.length} pages for $entityType');

    switch (entityType) {
      case 'HabitRecord':
        return _accumulateTyped<HabitRecord>(
          responseDtos,
          entityType,
          (dto) => dto.habitRecordsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(habitRecordsSyncData: data, totalItems: totalItems),
        );
      case 'AppUsageTimeRecord':
        return _accumulateTyped<AppUsageTimeRecord>(
          responseDtos,
          entityType,
          (dto) => dto.appUsageTimeRecordsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(appUsageTimeRecordsSyncData: data, totalItems: totalItems),
        );
      case 'Task':
        return _accumulateTyped<Task>(
          responseDtos,
          entityType,
          (dto) => dto.tasksSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(tasksSyncData: data, totalItems: totalItems),
        );
      case 'TaskTag':
        return _accumulateTyped<TaskTag>(
          responseDtos,
          entityType,
          (dto) => dto.taskTagsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(taskTagsSyncData: data, totalItems: totalItems),
        );
      case 'TaskTimeRecord':
        return _accumulateTyped<TaskTimeRecord>(
          responseDtos,
          entityType,
          (dto) => dto.taskTimeRecordsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(taskTimeRecordsSyncData: data, totalItems: totalItems),
        );
      case 'AppUsage':
        return _accumulateTyped<AppUsage>(
          responseDtos,
          entityType,
          (dto) => dto.appUsagesSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(appUsagesSyncData: data, totalItems: totalItems),
        );
      case 'AppUsageTag':
        return _accumulateTyped<AppUsageTag>(
          responseDtos,
          entityType,
          (dto) => dto.appUsageTagsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(appUsageTagsSyncData: data, totalItems: totalItems),
        );
      case 'Habit':
        return _accumulateTyped<Habit>(
          responseDtos,
          entityType,
          (dto) => dto.habitsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(habitsSyncData: data, totalItems: totalItems),
        );
      case 'HabitTag':
        return _accumulateTyped<HabitTag>(
          responseDtos,
          entityType,
          (dto) => dto.habitTagsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(habitTagsSyncData: data, totalItems: totalItems),
        );
      case 'Tag':
        return _accumulateTyped<Tag>(
          responseDtos,
          entityType,
          (dto) => dto.tagsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(tagsSyncData: data, totalItems: totalItems),
        );
      case 'Setting':
        return _accumulateTyped<Setting>(
          responseDtos,
          entityType,
          (dto) => dto.settingsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(settingsSyncData: data, totalItems: totalItems),
        );
      case 'Note':
        return _accumulateTyped<Note>(
          responseDtos,
          entityType,
          (dto) => dto.notesSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(notesSyncData: data, totalItems: totalItems),
        );
      case 'NoteTag':
        return _accumulateTyped<NoteTag>(
          responseDtos,
          entityType,
          (dto) => dto.noteTagsSyncData,
          (baseDto, data, totalItems) => baseDto.copyWith(noteTagsSyncData: data, totalItems: totalItems),
        );
      default:
        DomainLogger.warning('No accumulation logic for entity type: $entityType, using first page only');
        return responseDtos.first;
    }
  }

  /// Generic accumulation with type-safe extractor and builder
  PaginatedSyncDataDto _accumulateTyped<T extends BaseEntity>(
    List<PaginatedSyncDataDto> responseDtos,
    String entityType,
    PaginatedSyncData<T>? Function(PaginatedSyncDataDto dto) extractor,
    PaginatedSyncDataDto Function(PaginatedSyncDataDto baseDto, PaginatedSyncData<T> data, int totalItems) builder,
  ) {
    final baseDto = responseDtos.first;
    final allCreateSync = <T>[];
    final allUpdateSync = <T>[];
    final allDeleteSync = <T>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      final syncData = extractor(dto);
      if (syncData != null) {
        allCreateSync.addAll(syncData.data.createSync);
        allUpdateSync.addAll(syncData.data.updateSync);
        allDeleteSync.addAll(syncData.data.deleteSync);
        totalItems += syncData.data.getTotalItemCount();
      }
    }

    DomainLogger.info(
        'Accumulated $entityType data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<T>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<T>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: entityType,
    );

    return builder(baseDto, accumulatedPaginatedData, totalItems);
  }
}

/// Extension to add copyWith for building accumulated DTOs
extension PaginatedSyncDataDtoCopyWith on PaginatedSyncDataDto {
  PaginatedSyncDataDto copyWith({
    PaginatedSyncData<HabitRecord>? habitRecordsSyncData,
    PaginatedSyncData<AppUsageTimeRecord>? appUsageTimeRecordsSyncData,
    PaginatedSyncData<Task>? tasksSyncData,
    PaginatedSyncData<TaskTag>? taskTagsSyncData,
    PaginatedSyncData<TaskTimeRecord>? taskTimeRecordsSyncData,
    PaginatedSyncData<AppUsage>? appUsagesSyncData,
    PaginatedSyncData<AppUsageTag>? appUsageTagsSyncData,
    PaginatedSyncData<Habit>? habitsSyncData,
    PaginatedSyncData<HabitTag>? habitTagsSyncData,
    PaginatedSyncData<Tag>? tagsSyncData,
    PaginatedSyncData<Setting>? settingsSyncData,
    PaginatedSyncData<Note>? notesSyncData,
    PaginatedSyncData<NoteTag>? noteTagsSyncData,
    int? totalItems,
  }) {
    final items = totalItems ?? this.totalItems;
    return PaginatedSyncDataDto(
      appVersion: appVersion,
      syncDevice: syncDevice,
      isDebugMode: isDebugMode,
      entityType: entityType,
      pageIndex: 0,
      pageSize: items,
      totalPages: 1,
      totalItems: items,
      isLastPage: true,
      habitRecordsSyncData: habitRecordsSyncData ?? this.habitRecordsSyncData,
      appUsageTimeRecordsSyncData: appUsageTimeRecordsSyncData ?? this.appUsageTimeRecordsSyncData,
      tasksSyncData: tasksSyncData ?? this.tasksSyncData,
      taskTagsSyncData: taskTagsSyncData ?? this.taskTagsSyncData,
      taskTimeRecordsSyncData: taskTimeRecordsSyncData ?? this.taskTimeRecordsSyncData,
      appUsagesSyncData: appUsagesSyncData ?? this.appUsagesSyncData,
      appUsageTagsSyncData: appUsageTagsSyncData ?? this.appUsageTagsSyncData,
      habitsSyncData: habitsSyncData ?? this.habitsSyncData,
      habitTagsSyncData: habitTagsSyncData ?? this.habitTagsSyncData,
      tagsSyncData: tagsSyncData ?? this.tagsSyncData,
      settingsSyncData: settingsSyncData ?? this.settingsSyncData,
      notesSyncData: notesSyncData ?? this.notesSyncData,
      noteTagsSyncData: noteTagsSyncData ?? this.noteTagsSyncData,
    );
  }
}
