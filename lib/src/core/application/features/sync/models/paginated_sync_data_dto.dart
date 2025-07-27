import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/src/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';
import 'package:whph/src/core/domain/features/habits/habit_tag.dart';
import 'package:whph/src/core/domain/features/notes/note.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/task_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_ignore_rule.dart';

/// Paginated sync data transfer object for network transmission
@jsonSerializable
class PaginatedSyncDataDto {
  final String appVersion;
  final SyncDevice syncDevice;

  /// The entity type being synchronized in this chunk
  final String entityType;

  /// Pagination information
  final int pageIndex;
  final int pageSize;
  final int totalPages;
  final int totalItems;
  final bool isLastPage;

  /// Progress information
  final SyncProgress? progress;

  /// The actual paginated sync data - only one will be populated per message
  final PaginatedSyncData<AppUsage>? appUsagesSyncData;
  final PaginatedSyncData<AppUsageTag>? appUsageTagsSyncData;
  final PaginatedSyncData<AppUsageTimeRecord>? appUsageTimeRecordsSyncData;
  final PaginatedSyncData<AppUsageTagRule>? appUsageTagRulesSyncData;
  final PaginatedSyncData<AppUsageIgnoreRule>? appUsageIgnoreRulesSyncData;
  final PaginatedSyncData<Habit>? habitsSyncData;
  final PaginatedSyncData<HabitRecord>? habitRecordsSyncData;
  final PaginatedSyncData<HabitTag>? habitTagsSyncData;
  final PaginatedSyncData<Tag>? tagsSyncData;
  final PaginatedSyncData<TagTag>? tagTagsSyncData;
  final PaginatedSyncData<Task>? tasksSyncData;
  final PaginatedSyncData<TaskTag>? taskTagsSyncData;
  final PaginatedSyncData<TaskTimeRecord>? taskTimeRecordsSyncData;
  final PaginatedSyncData<Setting>? settingsSyncData;
  final PaginatedSyncData<SyncDevice>? syncDevicesSyncData;
  final PaginatedSyncData<Note>? notesSyncData;
  final PaginatedSyncData<NoteTag>? noteTagsSyncData;

  PaginatedSyncDataDto({
    required this.appVersion,
    required this.syncDevice,
    required this.entityType,
    required this.pageIndex,
    required this.pageSize,
    required this.totalPages,
    required this.totalItems,
    required this.isLastPage,
    this.progress,
    this.appUsagesSyncData,
    this.appUsageTagsSyncData,
    this.appUsageTimeRecordsSyncData,
    this.appUsageTagRulesSyncData,
    this.appUsageIgnoreRulesSyncData,
    this.habitsSyncData,
    this.habitRecordsSyncData,
    this.habitTagsSyncData,
    this.tagsSyncData,
    this.tagTagsSyncData,
    this.tasksSyncData,
    this.taskTagsSyncData,
    this.taskTimeRecordsSyncData,
    this.settingsSyncData,
    this.syncDevicesSyncData,
    this.notesSyncData,
    this.noteTagsSyncData,
  });

  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'syncDevice': syncDevice.toJson(),
        'entityType': entityType,
        'pageIndex': pageIndex,
        'pageSize': pageSize,
        'totalPages': totalPages,
        'totalItems': totalItems,
        'isLastPage': isLastPage,
        'progress': progress?.toJson(),
        'appUsagesSyncData': appUsagesSyncData?.toJson(),
        'appUsageTagsSyncData': appUsageTagsSyncData?.toJson(),
        'appUsageTimeRecordsSyncData': appUsageTimeRecordsSyncData?.toJson(),
        'appUsageTagRulesSyncData': appUsageTagRulesSyncData?.toJson(),
        'appUsageIgnoreRulesSyncData': appUsageIgnoreRulesSyncData?.toJson(),
        'habitsSyncData': habitsSyncData?.toJson(),
        'habitRecordsSyncData': habitRecordsSyncData?.toJson(),
        'habitTagsSyncData': habitTagsSyncData?.toJson(),
        'tagsSyncData': tagsSyncData?.toJson(),
        'tagTagsSyncData': tagTagsSyncData?.toJson(),
        'tasksSyncData': tasksSyncData?.toJson(),
        'taskTagsSyncData': taskTagsSyncData?.toJson(),
        'taskTimeRecordsSyncData': taskTimeRecordsSyncData?.toJson(),
        'settingsSyncData': settingsSyncData?.toJson(),
        'syncDevicesSyncData': syncDevicesSyncData?.toJson(),
        'notesSyncData': notesSyncData?.toJson(),
        'noteTagsSyncData': noteTagsSyncData?.toJson(),
      };

  factory PaginatedSyncDataDto.fromJson(Map<String, dynamic> json) {
    if (json['appVersion'] == null || json['appVersion'] is! String) {
      throw FormatException('Invalid or missing appVersion');
    }

    return PaginatedSyncDataDto(
      appVersion: json['appVersion'] as String,
      syncDevice: SyncDevice.fromJson(json['syncDevice'] as Map<String, dynamic>),
      entityType: json['entityType'] as String,
      pageIndex: json['pageIndex'] as int,
      pageSize: json['pageSize'] as int,
      totalPages: json['totalPages'] as int,
      totalItems: json['totalItems'] as int,
      isLastPage: json['isLastPage'] as bool,
      progress: json['progress'] != null ? SyncProgress.fromJson(json['progress'] as Map<String, dynamic>) : null,
      appUsagesSyncData: json['appUsagesSyncData'] != null
          ? PaginatedSyncData<AppUsage>.fromJson(json['appUsagesSyncData'] as Map<String, dynamic>, AppUsage)
          : null,
      appUsageTagsSyncData: json['appUsageTagsSyncData'] != null
          ? PaginatedSyncData<AppUsageTag>.fromJson(json['appUsageTagsSyncData'] as Map<String, dynamic>, AppUsageTag)
          : null,
      appUsageTimeRecordsSyncData: json['appUsageTimeRecordsSyncData'] != null
          ? PaginatedSyncData<AppUsageTimeRecord>.fromJson(
              json['appUsageTimeRecordsSyncData'] as Map<String, dynamic>, AppUsageTimeRecord)
          : null,
      appUsageTagRulesSyncData: json['appUsageTagRulesSyncData'] != null
          ? PaginatedSyncData<AppUsageTagRule>.fromJson(
              json['appUsageTagRulesSyncData'] as Map<String, dynamic>, AppUsageTagRule)
          : null,
      appUsageIgnoreRulesSyncData: json['appUsageIgnoreRulesSyncData'] != null
          ? PaginatedSyncData<AppUsageIgnoreRule>.fromJson(
              json['appUsageIgnoreRulesSyncData'] as Map<String, dynamic>, AppUsageIgnoreRule)
          : null,
      habitsSyncData: json['habitsSyncData'] != null
          ? PaginatedSyncData<Habit>.fromJson(json['habitsSyncData'] as Map<String, dynamic>, Habit)
          : null,
      habitRecordsSyncData: json['habitRecordsSyncData'] != null
          ? PaginatedSyncData<HabitRecord>.fromJson(json['habitRecordsSyncData'] as Map<String, dynamic>, HabitRecord)
          : null,
      habitTagsSyncData: json['habitTagsSyncData'] != null
          ? PaginatedSyncData<HabitTag>.fromJson(json['habitTagsSyncData'] as Map<String, dynamic>, HabitTag)
          : null,
      tagsSyncData: json['tagsSyncData'] != null
          ? PaginatedSyncData<Tag>.fromJson(json['tagsSyncData'] as Map<String, dynamic>, Tag)
          : null,
      tagTagsSyncData: json['tagTagsSyncData'] != null
          ? PaginatedSyncData<TagTag>.fromJson(json['tagTagsSyncData'] as Map<String, dynamic>, TagTag)
          : null,
      tasksSyncData: json['tasksSyncData'] != null
          ? PaginatedSyncData<Task>.fromJson(json['tasksSyncData'] as Map<String, dynamic>, Task)
          : null,
      taskTagsSyncData: json['taskTagsSyncData'] != null
          ? PaginatedSyncData<TaskTag>.fromJson(json['taskTagsSyncData'] as Map<String, dynamic>, TaskTag)
          : null,
      taskTimeRecordsSyncData: json['taskTimeRecordsSyncData'] != null
          ? PaginatedSyncData<TaskTimeRecord>.fromJson(
              json['taskTimeRecordsSyncData'] as Map<String, dynamic>, TaskTimeRecord)
          : null,
      settingsSyncData: json['settingsSyncData'] != null
          ? PaginatedSyncData<Setting>.fromJson(json['settingsSyncData'] as Map<String, dynamic>, Setting)
          : null,
      syncDevicesSyncData: json['syncDevicesSyncData'] != null
          ? PaginatedSyncData<SyncDevice>.fromJson(json['syncDevicesSyncData'] as Map<String, dynamic>, SyncDevice)
          : null,
      notesSyncData: json['notesSyncData'] != null
          ? PaginatedSyncData<Note>.fromJson(json['notesSyncData'] as Map<String, dynamic>, Note)
          : null,
      noteTagsSyncData: json['noteTagsSyncData'] != null
          ? PaginatedSyncData<NoteTag>.fromJson(json['noteTagsSyncData'] as Map<String, dynamic>, NoteTag)
          : null,
    );
  }

  /// Helper method to get the populated sync data regardless of type
  PaginatedSyncData<dynamic>? getPopulatedSyncData() {
    return appUsagesSyncData ??
        appUsageTagsSyncData ??
        appUsageTimeRecordsSyncData ??
        appUsageTagRulesSyncData ??
        appUsageIgnoreRulesSyncData ??
        habitsSyncData ??
        habitRecordsSyncData ??
        habitTagsSyncData ??
        tagsSyncData ??
        tagTagsSyncData ??
        tasksSyncData ??
        taskTagsSyncData ??
        taskTimeRecordsSyncData ??
        settingsSyncData ??
        syncDevicesSyncData ??
        notesSyncData ??
        noteTagsSyncData;
  }
}
