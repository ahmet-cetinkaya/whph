import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

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
  final HabitType type;
  final HabitDayState dailyState;
  final bool isCompletedToday;
  final bool hasGoal;
  final int dailyTarget;
  final int currentCompletionCount;
  final bool isDailyGoalMet;
  final DateTime? completedAt; // When the habit reached its daily target
  final int targetFrequency; // Period-based goal: how many times
  final int periodDays; // Period-based goal: over how many days
  final bool isPeriodGoalMet; // Whether the period-based goal is satisfied

  WidgetHabitData({
    required this.id,
    required this.name,
    this.type = HabitType.good,
    this.dailyState = HabitDayState.incomplete,
    required this.isCompletedToday,
    this.hasGoal = false,
    this.dailyTarget = 1,
    this.currentCompletionCount = 0,
    this.isDailyGoalMet = false,
    this.completedAt,
    this.targetFrequency = 1,
    this.periodDays = 1,
    this.isPeriodGoalMet = false,
  });

  factory WidgetHabitData.fromJson(Map<String, dynamic> json) {
    return WidgetHabitData(
      id: json['id'] as String,
      name: json['name'] as String,
      // The widget blob outlives app upgrades and downgrades, so an unknown name
      // from a newer version must degrade to the default instead of throwing.
      type: HabitType.fromJson(json['type']),
      dailyState: HabitDayState.values.asNameMap()[json['dailyState']] ?? HabitDayState.incomplete,
      isCompletedToday: json['isCompletedToday'] as bool,
      hasGoal: json['hasGoal'] as bool? ?? false,
      dailyTarget: json['dailyTarget'] as int? ?? 1,
      currentCompletionCount: json['currentCompletionCount'] as int? ?? 0,
      isDailyGoalMet: json['isDailyGoalMet'] as bool? ?? false,
      completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      targetFrequency: json['targetFrequency'] as int? ?? 1,
      periodDays: json['periodDays'] as int? ?? 1,
      isPeriodGoalMet: json['isPeriodGoalMet'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'dailyState': dailyState.name,
        'isCompletedToday': isCompletedToday,
        'hasGoal': hasGoal,
        'dailyTarget': dailyTarget,
        'currentCompletionCount': currentCompletionCount,
        'isDailyGoalMet': isDailyGoalMet,
        'completedAt': completedAt?.toIso8601String(),
        'targetFrequency': targetFrequency,
        'periodDays': periodDays,
        'isPeriodGoalMet': isPeriodGoalMet,
      };
}

@jsonSerializable
class WidgetData {
  final List<WidgetTaskData> tasks;
  final List<WidgetHabitData> habits;
  final DateTime lastUpdated;
  final String tasksTitle;
  final String habitsTitle;
  final String noPendingTasks;
  final String noPendingHabits;
  final String todayLabel;

  WidgetData({
    required this.tasks,
    required this.habits,
    required this.lastUpdated,
    this.tasksTitle = 'Tasks',
    this.habitsTitle = 'Habits',
    this.noPendingTasks = 'No pending tasks',
    this.noPendingHabits = 'No pending habits',
    this.todayLabel = 'Today',
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
      'habits': habits.map((habit) => habit.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'localizedStrings': {
        'tasksTitle': tasksTitle,
        'habitsTitle': habitsTitle,
        'noPendingTasks': noPendingTasks,
        'noPendingHabits': noPendingHabits,
        'todayLabel': todayLabel,
      },
    };
  }
}
