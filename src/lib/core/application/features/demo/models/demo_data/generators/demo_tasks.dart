import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Demo task data generator
class DemoTasks {
  /// Demo tasks to be created
  static List<Task> get tasks {
    final buyGroceriesTaskId = KeyHelper.generateStringId();

    return [
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Complete Project Proposal',
        description: 'Prepare and submit the quarterly project proposal for review',
        completedAt: null,
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 2)),
        deadlineDate: DateTime.now().add(const Duration(days: 5)),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Team Performance',
        description: 'Conduct quarterly performance reviews for team members',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)),
        deadlineDate: DateTime.now().add(const Duration(days: 14)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Update Resume',
        description: 'Add recent projects and achievements to resume',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 10)),
        createdDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Task(
        id: buyGroceriesTaskId,
        title: 'Buy Groceries',
        description: 'Weekly grocery shopping for the household',
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now(),
      ),
      // Subtasks for Buy Groceries
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Fresh Vegetables',
        description: 'Tomatoes, lettuce, carrots, onions, peppers',
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Dairy Products',
        description: 'Milk, cheese, yogurt, butter',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Meat & Protein',
        description: 'Chicken breast, ground beef, eggs, salmon',
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Pantry Staples',
        description: 'Rice, pasta, bread, olive oil, spices',
        completedAt: null,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Household Items',
        description: 'Toilet paper, cleaning supplies, laundry detergent',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(),
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn Microservices Architecture Patterns',
        description:
            'Study distributed system design patterns including circuit breaker, saga, and event sourcing for scalable applications',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)),
        createdDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Call Mom',
        description: 'Weekly check-in call with family',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Code Changes',
        description: 'Review and approve pending pull requests',
        completedAt: null,
        priority: EisenhowerPriority.urgentImportant,
        deadlineDate: DateTime.now().add(const Duration(hours: 5)),
        createdDate: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Backup Computer Files',
        description: 'Weekly backup of important documents and projects',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 1)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn Flutter State Management',
        description: 'Complete online course on advanced Flutter state management patterns',
        completedAt: null,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 3)),
        deadlineDate: DateTime.now().add(const Duration(days: 21)),
        createdDate: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Study Design Patterns',
        description: 'Review and practice implementing key design patterns: Observer, Factory, and Strategy patterns',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn API Documentation',
        description: 'Study REST API best practices and OpenAPI specification',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Schedule Annual Health Checkup',
        description: 'Book appointment with primary care physician for annual checkup',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().subtract(const Duration(days: 2)),
        createdDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Morning Emails',
        description: 'Check and respond to priority emails from overnight',
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
            duration: duration.inMilliseconds,
            createdDate: recordDate,
          ));
        }
      }
    }

    return records;
  }
}
