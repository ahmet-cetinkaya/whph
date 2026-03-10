import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

@jsonSerializable
class SyncData<T extends BaseEntity<dynamic>> {
  List<T> createSync = [];
  List<T> updateSync = [];
  List<T> deleteSync = [];

  SyncData({
    required this.createSync,
    required this.updateSync,
    required this.deleteSync,
  });

  /// Get the total count of all items in this sync data
  int getTotalItemCount() {
    return createSync.length + updateSync.length + deleteSync.length;
  }

  Map<String, dynamic> toJson() => {
        'createSync': createSync.map((e) => e.toJson()).toList(),
        'updateSync': updateSync.map((e) => e.toJson()).toList(),
        'deleteSync': deleteSync.map((e) => e.toJson()).toList(),
      };

  factory SyncData.fromJson(Map<String, dynamic> json, Type type) {
    return SyncData(
      createSync: (json['createSync'] as List)
          .map((e) => _deserializeEntity<T>(e as Map<String, dynamic>, type))
          .whereType<T>() // Filter out null values
          .toList(),
      updateSync: (json['updateSync'] as List)
          .map((e) => _deserializeEntity<T>(e as Map<String, dynamic>, type))
          .whereType<T>()
          .toList(),
      deleteSync: (json['deleteSync'] as List)
          .map((e) => _deserializeEntity<T>(e as Map<String, dynamic>, type))
          .whereType<T>()
          .toList(),
    );
  }

  /// Type-safe deserialization map to avoid issues with minified builds
  static final Map<Type, dynamic Function(Map<String, dynamic>)> _deserializationMap = {
    Task: (json) => Task.fromJson(json),
    AppUsage: (json) => AppUsage.fromJson(json),
    AppUsageTag: (json) => AppUsageTag.fromJson(json),
    AppUsageTimeRecord: (json) => AppUsageTimeRecord.fromJson(json),
    AppUsageTagRule: (json) => AppUsageTagRule.fromJson(json),
    AppUsageIgnoreRule: (json) => AppUsageIgnoreRule.fromJson(json),
    Habit: (json) => Habit.fromJson(json),
    HabitRecord: (json) => HabitRecord.fromJson(json),
    HabitTag: (json) => HabitTag.fromJson(json),
    Tag: (json) => Tag.fromJson(json),
    TagTag: (json) => TagTag.fromJson(json),
    TaskTag: (json) => TaskTag.fromJson(json),
    TaskTimeRecord: (json) => TaskTimeRecord.fromJson(json),
    Setting: (json) => Setting.fromJson(json),
    SyncDevice: (json) => SyncDevice.fromJson(json),
    Note: (json) => Note.fromJson(json),
    NoteTag: (json) => NoteTag.fromJson(json),
  };

  /// Helper method to deserialize entities using their fromJson factory constructors
  static T? _deserializeEntity<T>(Map<String, dynamic> json, Type type) {
    try {
      // Use type-safe deserialization map instead of type.toString() to avoid minification issues
      final deserializer = _deserializationMap[type];
      if (deserializer != null) {
        return deserializer(json) as T?;
      }

      // Fallback to JsonMapper.deserialize for unknown types
      return JsonMapper.deserialize<T>(json);
    } catch (e) {
      // Log the error but continue processing other entities
      Logger.error('Error deserializing ${type.toString()}: $e');
      return null;
    }
  }
}
