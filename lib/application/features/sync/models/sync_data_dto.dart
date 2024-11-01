import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';

@jsonSerializable
class SyncDataDto {
  SyncData<AppUsage> appUsagesSyncData;
  SyncData<AppUsageTag> appUsageTagsSyncData;
  SyncData<Habit> habitsSyncData;
  SyncData<HabitRecord> habitRecordsSyncData;
  SyncData<Tag> tagsSyncData;
  SyncData<TagTag> tagTagsSyncData;
  SyncData<Task> tasksSyncData;
  SyncData<TaskTag> taskTagsSyncData;
  SyncData<Setting> settingsSyncData;
  SyncData<SyncDevice> syncDevicesSyncData;
  SyncDevice syncDevice;

  SyncDataDto(
      {required this.appUsagesSyncData,
      required this.appUsageTagsSyncData,
      required this.habitsSyncData,
      required this.habitRecordsSyncData,
      required this.tagsSyncData,
      required this.tagTagsSyncData,
      required this.tasksSyncData,
      required this.taskTagsSyncData,
      required this.settingsSyncData,
      required this.syncDevicesSyncData,
      required this.syncDevice});

  factory SyncDataDto.fromJson(Map<String, dynamic> json) => SyncDataDto(
      appUsagesSyncData: SyncData<AppUsage>(
        createSync: (json['appUsagesSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsage>(e)!)
            .toList(),
        updateSync: (json['appUsagesSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsage>(e)!)
            .toList(),
        deleteSync: (json['appUsagesSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsage>(e)!)
            .toList(),
      ),
      appUsageTagsSyncData: SyncData<AppUsageTag>(
        createSync: (json['appUsageTagsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsageTag>(e)!)
            .toList(),
        updateSync: (json['appUsageTagsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsageTag>(e)!)
            .toList(),
        deleteSync: (json['appUsageTagsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<AppUsageTag>(e)!)
            .toList(),
      ),
      habitRecordsSyncData: SyncData<HabitRecord>(
        createSync: (json['habitRecordsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<HabitRecord>(e)!)
            .toList(),
        updateSync: (json['habitRecordsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<HabitRecord>(e)!)
            .toList(),
        deleteSync: (json['habitRecordsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<HabitRecord>(e)!)
            .toList(),
      ),
      habitsSyncData: SyncData<Habit>(
        createSync: (json['habitsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Habit>(e)!)
            .toList(),
        updateSync: (json['habitsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Habit>(e)!)
            .toList(),
        deleteSync: (json['habitsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Habit>(e)!)
            .toList(),
      ),
      settingsSyncData: SyncData<Setting>(
        createSync: (json['settingsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Setting>(e)!)
            .toList(),
        updateSync: (json['settingsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Setting>(e)!)
            .toList(),
        deleteSync: (json['settingsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Setting>(e)!)
            .toList(),
      ),
      tagTagsSyncData: SyncData<TagTag>(
        createSync: (json['tagTagsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TagTag>(e)!)
            .toList(),
        updateSync: (json['tagTagsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TagTag>(e)!)
            .toList(),
        deleteSync: (json['tagTagsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TagTag>(e)!)
            .toList(),
      ),
      tagsSyncData: SyncData<Tag>(
        createSync:
            (json['tagsSyncData']['createSync'] as List<dynamic>).map((e) => JsonMapper.deserialize<Tag>(e)!).toList(),
        updateSync:
            (json['tagsSyncData']['updateSync'] as List<dynamic>).map((e) => JsonMapper.deserialize<Tag>(e)!).toList(),
        deleteSync:
            (json['tagsSyncData']['deleteSync'] as List<dynamic>).map((e) => JsonMapper.deserialize<Tag>(e)!).toList(),
      ),
      taskTagsSyncData: SyncData<TaskTag>(
        createSync: (json['taskTagsSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TaskTag>(e)!)
            .toList(),
        updateSync: (json['taskTagsSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TaskTag>(e)!)
            .toList(),
        deleteSync: (json['taskTagsSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<TaskTag>(e)!)
            .toList(),
      ),
      tasksSyncData: SyncData<Task>(
        createSync: (json['tasksSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Task>(e)!)
            .toList(),
        updateSync: (json['tasksSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Task>(e)!)
            .toList(),
        deleteSync: (json['tasksSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<Task>(e)!)
            .toList(),
      ),
      syncDevicesSyncData: SyncData<SyncDevice>(
        createSync: (json['syncDevicesSyncData']['createSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<SyncDevice>(e)!)
            .toList(),
        updateSync: (json['syncDevicesSyncData']['updateSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<SyncDevice>(e)!)
            .toList(),
        deleteSync: (json['syncDevicesSyncData']['deleteSync'] as List<dynamic>)
            .map((e) => JsonMapper.deserialize<SyncDevice>(e)!)
            .toList(),
      ),
      syncDevice: JsonMapper.deserialize<SyncDevice>(json['syncDevice'])!);
}
