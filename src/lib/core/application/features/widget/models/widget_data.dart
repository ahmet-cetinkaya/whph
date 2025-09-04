import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class WidgetTaskData {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;

  WidgetTaskData({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.plannedDate,
    this.deadlineDate,
  });
}

@jsonSerializable
class WidgetHabitData {
  final String id;
  final String name;
  final bool isCompletedToday;

  WidgetHabitData({
    required this.id,
    required this.name,
    required this.isCompletedToday,
  });
}

@jsonSerializable
class WidgetData {
  final List<WidgetTaskData> tasks;
  final List<WidgetHabitData> habits;
  final DateTime lastUpdated;

  WidgetData({
    required this.tasks,
    required this.habits,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'tasks': tasks
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'isCompleted': t.isCompleted,
                'plannedDate': t.plannedDate?.toIso8601String(),
                'deadlineDate': t.deadlineDate?.toIso8601String(),
              })
          .toList(),
      'habits': habits
          .map((h) => {
                'id': h.id,
                'name': h.name,
                'isCompletedToday': h.isCompletedToday,
              })
          .toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
