import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';

class HabitListItem {
  String id;
  String name;
  List<TagListItem> tags;
  int? estimatedTime;
  int? actualTime; // Total logged time in minutes
  bool hasReminder;
  String? reminderTime;
  List<int> reminderDays;
  DateTime? archivedDate;
  double? order;
  bool hasGoal;
  int? dailyTarget;
  int targetFrequency;
  int periodDays;
  String? groupName;

  HabitListItem({
    required this.id,
    required this.name,
    this.tags = const [],
    this.estimatedTime,
    this.actualTime,
    this.hasReminder = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.archivedDate,
    this.order,
    this.hasGoal = false,
    this.dailyTarget,
    this.targetFrequency = 1,
    this.periodDays = 1,
    this.groupName,
  });

  bool isArchived() {
    return archivedDate != null;
  }
}
