import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/application/features/sync/models/sync_data.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/domain/features/notes/note.dart';
import 'package:whph/domain/features/notes/note_tag.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/domain/features/tasks/task_time_record.dart';
import 'package:whph/domain/features/app_usages/app_usage_ignore_rule.dart';

@jsonSerializable
class SyncDataDto {
  final String appVersion;
  SyncData<AppUsage>? appUsagesSyncData;
  SyncData<AppUsageTag>? appUsageTagsSyncData;
  SyncData<AppUsageTimeRecord>? appUsageTimeRecordsSyncData;
  SyncData<AppUsageTagRule>? appUsageTagRulesSyncData;
  SyncData<AppUsageIgnoreRule>? appUsageIgnoreRulesSyncData;
  SyncData<Habit>? habitsSyncData;
  SyncData<HabitRecord>? habitRecordsSyncData;
  SyncData<HabitTag>? habitTagsSyncData;
  SyncData<Tag>? tagsSyncData;
  SyncData<TagTag>? tagTagsSyncData;
  SyncData<Task>? tasksSyncData;
  SyncData<TaskTag>? taskTagsSyncData;
  SyncData<TaskTimeRecord>? taskTimeRecordsSyncData;
  SyncData<Setting>? settingsSyncData;
  SyncData<SyncDevice>? syncDevicesSyncData;
  SyncData<Note>? notesSyncData;
  SyncData<NoteTag>? noteTagsSyncData;
  SyncDevice syncDevice;

  SyncDataDto({
    required this.appVersion,
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
    required this.syncDevice,
  });

  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'appUsagesSyncData': appUsagesSyncData,
        'appUsageTagsSyncData': appUsageTagsSyncData,
        'appUsageTimeRecordsSyncData': appUsageTimeRecordsSyncData,
        'appUsageTagRulesSyncData': appUsageTagRulesSyncData,
        'appUsageIgnoreRulesSyncData': appUsageIgnoreRulesSyncData,
        'habitsSyncData': habitsSyncData,
        'habitRecordsSyncData': habitRecordsSyncData,
        'habitTagsSyncData': habitTagsSyncData,
        'tagsSyncData': tagsSyncData,
        'tagTagsSyncData': tagTagsSyncData,
        'tasksSyncData': tasksSyncData,
        'taskTagsSyncData': taskTagsSyncData,
        'taskTimeRecordsSyncData': taskTimeRecordsSyncData,
        'settingsSyncData': settingsSyncData,
        'syncDevicesSyncData': syncDevicesSyncData,
        'syncDevice': syncDevice,
        'notesSyncData': notesSyncData,
        'noteTagsSyncData': noteTagsSyncData,
      };

  factory SyncDataDto.fromJson(Map<String, dynamic> json) {
    if (json['appVersion'] == null || json['appVersion'] is! String) {
      throw FormatException('Invalid or missing appVersion');
    }

    return SyncDataDto(
      appVersion: json['appVersion'] as String,
      syncDevice: SyncDevice.fromJson(json['syncDevice'] as Map<String, dynamic>),
      appUsagesSyncData: json['appUsagesSyncData'] != null
          ? SyncData<AppUsage>.fromJson(json['appUsagesSyncData'] as Map<String, dynamic>, AppUsage)
          : SyncData<AppUsage>(createSync: [], updateSync: [], deleteSync: []),
      appUsageTagsSyncData: json['appUsageTagsSyncData'] != null
          ? SyncData<AppUsageTag>.fromJson(json['appUsageTagsSyncData'] as Map<String, dynamic>, AppUsageTag)
          : SyncData<AppUsageTag>(createSync: [], updateSync: [], deleteSync: []),
      appUsageTimeRecordsSyncData: json['appUsageTimeRecordsSyncData'] != null
          ? SyncData<AppUsageTimeRecord>.fromJson(
              json['appUsageTimeRecordsSyncData'] as Map<String, dynamic>, AppUsageTimeRecord)
          : SyncData<AppUsageTimeRecord>(createSync: [], updateSync: [], deleteSync: []),
      appUsageTagRulesSyncData: json['appUsageTagRulesSyncData'] != null
          ? SyncData<AppUsageTagRule>.fromJson(
              json['appUsageTagRulesSyncData'] as Map<String, dynamic>, AppUsageTagRule)
          : SyncData<AppUsageTagRule>(createSync: [], updateSync: [], deleteSync: []),
      appUsageIgnoreRulesSyncData: json['appUsageIgnoreRulesSyncData'] != null
          ? SyncData<AppUsageIgnoreRule>.fromJson(
              json['appUsageIgnoreRulesSyncData'] as Map<String, dynamic>, AppUsageIgnoreRule)
          : SyncData<AppUsageIgnoreRule>(createSync: [], updateSync: [], deleteSync: []),
      habitsSyncData: json['habitsSyncData'] != null
          ? SyncData<Habit>.fromJson(json['habitsSyncData'] as Map<String, dynamic>, Habit)
          : SyncData<Habit>(createSync: [], updateSync: [], deleteSync: []),
      habitRecordsSyncData: json['habitRecordsSyncData'] != null
          ? SyncData<HabitRecord>.fromJson(json['habitRecordsSyncData'] as Map<String, dynamic>, HabitRecord)
          : SyncData<HabitRecord>(createSync: [], updateSync: [], deleteSync: []),
      habitTagsSyncData: json['habitTagsSyncData'] != null
          ? SyncData<HabitTag>.fromJson(json['habitTagsSyncData'] as Map<String, dynamic>, HabitTag)
          : SyncData<HabitTag>(createSync: [], updateSync: [], deleteSync: []),
      tagsSyncData: json['tagsSyncData'] != null
          ? SyncData<Tag>.fromJson(json['tagsSyncData'] as Map<String, dynamic>, Tag)
          : SyncData<Tag>(createSync: [], updateSync: [], deleteSync: []),
      tagTagsSyncData: json['tagTagsSyncData'] != null
          ? SyncData<TagTag>.fromJson(json['tagTagsSyncData'] as Map<String, dynamic>, TagTag)
          : SyncData<TagTag>(createSync: [], updateSync: [], deleteSync: []),
      tasksSyncData: json['tasksSyncData'] != null
          ? SyncData<Task>.fromJson(json['tasksSyncData'] as Map<String, dynamic>, Task)
          : SyncData<Task>(createSync: [], updateSync: [], deleteSync: []),
      taskTagsSyncData: json['taskTagsSyncData'] != null
          ? SyncData<TaskTag>.fromJson(json['taskTagsSyncData'] as Map<String, dynamic>, TaskTag)
          : SyncData<TaskTag>(createSync: [], updateSync: [], deleteSync: []),
      taskTimeRecordsSyncData: json['taskTimeRecordsSyncData'] != null
          ? SyncData<TaskTimeRecord>.fromJson(json['taskTimeRecordsSyncData'] as Map<String, dynamic>, TaskTimeRecord)
          : SyncData<TaskTimeRecord>(createSync: [], updateSync: [], deleteSync: []),
      settingsSyncData: json['settingsSyncData'] != null
          ? SyncData<Setting>.fromJson(json['settingsSyncData'] as Map<String, dynamic>, Setting)
          : SyncData<Setting>(createSync: [], updateSync: [], deleteSync: []),
      syncDevicesSyncData: json['syncDevicesSyncData'] != null
          ? SyncData<SyncDevice>.fromJson(json['syncDevicesSyncData'] as Map<String, dynamic>, SyncDevice)
          : SyncData<SyncDevice>(createSync: [], updateSync: [], deleteSync: []),
      notesSyncData: json['notesSyncData'] != null
          ? SyncData<Note>.fromJson(json['notesSyncData'] as Map<String, dynamic>, Note)
          : SyncData<Note>(createSync: [], updateSync: [], deleteSync: []),
      noteTagsSyncData: json['noteTagsSyncData'] != null
          ? SyncData<NoteTag>.fromJson(json['noteTagsSyncData'] as Map<String, dynamic>, NoteTag)
          : SyncData<NoteTag>(createSync: [], updateSync: [], deleteSync: []),
    );
  }
}
