import 'package:application/features/tags/queries/get_list_tags_query.dart';

class HabitListItem {
  final String id;
  final String name;
  final List<TagListItem> tags;
  final int? estimatedTime;
  final int? actualTime; // Total logged time in minutes
  final bool hasReminder;
  final String? reminderTime;
  final List<int> reminderDays;
  final DateTime? archivedDate;
  final DateTime? createdDate;
  final DateTime? modifiedDate;
  final double? order;
  final bool hasGoal;
  final int? dailyTarget;
  final int targetFrequency;
  final int periodDays;
  final String? groupName;

  const HabitListItem({
    required this.id,
    required this.name,
    this.tags = const [],
    this.estimatedTime,
    this.actualTime,
    this.hasReminder = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.archivedDate,
    this.createdDate,
    this.modifiedDate,
    this.order,
    this.hasGoal = false,
    this.dailyTarget,
    this.targetFrequency = 1,
    this.periodDays = 1,
    this.groupName,
  });

  bool get isArchived => archivedDate != null;

  HabitListItem copyWith({
    String? id,
    String? name,
    List<TagListItem>? tags,
    int? estimatedTime,
    int? actualTime,
    bool? hasReminder,
    String? reminderTime,
    List<int>? reminderDays,
    DateTime? archivedDate,
    DateTime? createdDate,
    DateTime? modifiedDate,
    double? order,
    bool? hasGoal,
    int? dailyTarget,
    int? targetFrequency,
    int? periodDays,
    String? groupName,
  }) {
    return HabitListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      tags: tags ?? this.tags,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      actualTime: actualTime ?? this.actualTime,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      archivedDate: archivedDate ?? this.archivedDate,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      order: order ?? this.order,
      hasGoal: hasGoal ?? this.hasGoal,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      targetFrequency: targetFrequency ?? this.targetFrequency,
      periodDays: periodDays ?? this.periodDays,
      groupName: groupName ?? this.groupName,
    );
  }
}
