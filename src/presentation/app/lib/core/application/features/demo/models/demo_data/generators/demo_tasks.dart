import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/demo/constants/demo_translation_keys.dart';

/// Demo task data generator
class DemoTasks {
  /// Demo tasks using translation function
  static List<Task> getTasks(String Function(String) translate) {
    final buyGroceriesTaskId = KeyHelper.generateStringId();

    return [
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskCompleteProjectTitle),
        description: translate(DemoTranslationKeys.taskCompleteProjectDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 2)),
        deadlineDate: DateTime.now().add(const Duration(days: 5)),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskReviewTeamTitle),
        description: translate(DemoTranslationKeys.taskReviewTeamDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)),
        deadlineDate: DateTime.now().add(const Duration(days: 14)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskUpdateResumeTitle),
        description: translate(DemoTranslationKeys.taskUpdateResumeDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 10)),
        createdDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Task(
        id: buyGroceriesTaskId,
        title: translate(DemoTranslationKeys.taskBuyGroceriesTitle),
        description: translate(DemoTranslationKeys.taskBuyGroceriesDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now(),
      ),
      // Subtasks for Buy Groceries
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBuyVegetablesTitle),
        description: translate(DemoTranslationKeys.taskBuyVegetablesDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBuyDairyTitle),
        description: translate(DemoTranslationKeys.taskBuyDairyDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBuyMeatTitle),
        description: translate(DemoTranslationKeys.taskBuyMeatDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBuyPantryTitle),
        description: translate(DemoTranslationKeys.taskBuyPantryDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBuyHouseholdTitle),
        description: translate(DemoTranslationKeys.taskBuyHouseholdDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskLearnMicroservicesTitle),
        description: translate(DemoTranslationKeys.taskLearnMicroservicesDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)),
        createdDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskCallMomTitle),
        description: translate(DemoTranslationKeys.taskCallMomDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskReviewCodeTitle),
        description: translate(DemoTranslationKeys.taskReviewCodeDescription),
        completedAt: null,
        priority: EisenhowerPriority.urgentImportant,
        deadlineDate: DateTime.now().add(const Duration(hours: 5)),
        createdDate: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskBackupFilesTitle),
        description: translate(DemoTranslationKeys.taskBackupFilesDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 1)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskLearnFlutterTitle),
        description: translate(DemoTranslationKeys.taskLearnFlutterDescription),
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 3)),
        deadlineDate: DateTime.now().add(const Duration(days: 21)),
        createdDate: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskStudyPatternsTitle),
        description: translate(DemoTranslationKeys.taskStudyPatternsDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskLearnApiTitle),
        description: translate(DemoTranslationKeys.taskLearnApiDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskHealthCheckupTitle),
        description: translate(DemoTranslationKeys.taskHealthCheckupDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().subtract(const Duration(days: 2)),
        createdDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: translate(DemoTranslationKeys.taskReviewEmailsTitle),
        description: translate(DemoTranslationKeys.taskReviewEmailsDescription),
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  /// Generates task time records for demo tasks
  static List<TaskTimeRecord> generateTimeRecords(List<Task> tasks) {
    final records = <TaskTimeRecord>[];
    final now = DateTime.now();

    for (final task in tasks) {
      // Only generate records for completed tasks or tasks worked on
      if (task.completedAt != null || task.priority == EisenhowerPriority.urgentImportant) {
        final recordCount = task.completedAt != null ? 3 : 1;

        for (int i = 0; i < recordCount; i++) {
          final duration = Duration(minutes: 15 + (i * 10) + (task.title.length % 20));
          final recordDate = task.completedAt ?? now.subtract(Duration(hours: i + 1));

          records.add(TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: task.id,
            duration: duration.inSeconds,
            createdDate: recordDate,
          ));
        }
      }
    }

    return records;
  }
}
