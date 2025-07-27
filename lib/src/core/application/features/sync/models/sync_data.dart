import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';
import 'package:whph/src/core/domain/features/habits/habit_tag.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/task_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/domain/features/notes/note.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

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

  /// Helper method to deserialize entities using their fromJson factory constructors
  static T? _deserializeEntity<T>(Map<String, dynamic> json, Type type) {
    try {
      // Use the entity's own fromJson method instead of JsonMapper.deserialize
      // This ensures proper type conversion handling (e.g., int to double)
      switch (type.toString()) {
        case 'Task':
          return Task.fromJson(json) as T?;
        case 'AppUsage':
          return AppUsage.fromJson(json) as T?;
        case 'AppUsageTag':
          return AppUsageTag.fromJson(json) as T?;
        case 'AppUsageTimeRecord':
          return AppUsageTimeRecord.fromJson(json) as T?;
        case 'AppUsageTagRule':
          return AppUsageTagRule.fromJson(json) as T?;
        case 'AppUsageIgnoreRule':
          return AppUsageIgnoreRule.fromJson(json) as T?;
        case 'Habit':
          return Habit.fromJson(json) as T?;
        case 'HabitRecord':
          return HabitRecord.fromJson(json) as T?;
        case 'HabitTag':
          return HabitTag.fromJson(json) as T?;
        case 'Tag':
          return Tag.fromJson(json) as T?;
        case 'TagTag':
          return TagTag.fromJson(json) as T?;
        case 'TaskTag':
          return TaskTag.fromJson(json) as T?;
        case 'TaskTimeRecord':
          return TaskTimeRecord.fromJson(json) as T?;
        case 'Setting':
          return Setting.fromJson(json) as T?;
        case 'SyncDevice':
          return SyncDevice.fromJson(json) as T?;
        case 'Note':
          return Note.fromJson(json) as T?;
        case 'NoteTag':
          return NoteTag.fromJson(json) as T?;
        default:
          // Fallback to JsonMapper.deserialize for unknown types
          return JsonMapper.deserialize<T>(json);
      }
    } catch (e) {
      // Log the error but continue processing other entities
      Logger.error('Error deserializing ${type.toString()}: $e');
      return null;
    }
  }
}
