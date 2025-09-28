import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

void main() {
  group('SaveTaskCommand Tests', () {
    group('Command Creation', () {
      test('should create command with basic properties', () {
        // Arrange
        const title = 'Test Task';
        const description = 'Test Description';
        final plannedDate = DateTime.utc(2024, 1, 15);

        // Act
        final command = SaveTaskCommand(
          title: title,
          description: description,
          plannedDate: plannedDate,
        );

        // Assert
        expect(command.title, title);
        expect(command.description, description);
        expect(command.plannedDate?.day, plannedDate.day);
        expect(command.isCompleted, false); // default value
      });

      test('should create command with recurrence properties', () {
        // Arrange
        const title = 'Recurring Task';
        final plannedDate = DateTime.utc(2024, 1, 15);
        const recurrenceType = RecurrenceType.daily;
        const recurrenceInterval = 2;
        final recurrenceDays = [WeekDays.monday, WeekDays.wednesday];
        final recurrenceStartDate = DateTime.utc(2024, 1, 1);
        final recurrenceEndDate = DateTime.utc(2024, 12, 31);
        const recurrenceCount = 10;

        // Act
        final command = SaveTaskCommand(
          title: title,
          plannedDate: plannedDate,
          recurrenceType: recurrenceType,
          recurrenceInterval: recurrenceInterval,
          recurrenceDays: recurrenceDays,
          recurrenceStartDate: recurrenceStartDate,
          recurrenceEndDate: recurrenceEndDate,
          recurrenceCount: recurrenceCount,
        );

        // Assert
        expect(command.title, title);
        expect(command.recurrenceType, recurrenceType);
        expect(command.recurrenceInterval, recurrenceInterval);
        expect(command.recurrenceDays, recurrenceDays);
        expect(command.recurrenceStartDate?.day, recurrenceStartDate.day);
        expect(command.recurrenceEndDate?.day, recurrenceEndDate.day);
        expect(command.recurrenceCount, recurrenceCount);
      });

      test('should create command with recurrenceParentId for recurring task instances', () {
        // Arrange
        const title = 'Recurring Task Instance';
        final plannedDate = DateTime(2024, 1, 15);
        const recurrenceType = RecurrenceType.daily;
        const recurrenceParentId = 'parent-task-123';

        // Act
        final command = SaveTaskCommand(
          title: title,
          plannedDate: plannedDate,
          recurrenceType: recurrenceType,
          recurrenceParentId: recurrenceParentId,
        );

        // Assert
        expect(command.title, title);
        expect(command.recurrenceType, recurrenceType);
        expect(command.recurrenceParentId, recurrenceParentId);
      });

      test('should create command with all reminder properties', () {
        // Arrange
        const title = 'Task with Reminders';
        final plannedDate = DateTime.utc(2024, 1, 15);
        final deadlineDate = DateTime.utc(2024, 1, 20);
        const plannedReminderTime = ReminderTime.fiveMinutesBefore;
        const deadlineReminderTime = ReminderTime.oneHourBefore;

        // Act
        final command = SaveTaskCommand(
          title: title,
          plannedDate: plannedDate,
          deadlineDate: deadlineDate,
          plannedDateReminderTime: plannedReminderTime,
          deadlineDateReminderTime: deadlineReminderTime,
        );

        // Assert
        expect(command.title, title);
        expect(command.plannedDate?.day, plannedDate.day);
        expect(command.deadlineDate?.day, deadlineDate.day);
        expect(command.plannedDateReminderTime, plannedReminderTime);
        expect(command.deadlineDateReminderTime, deadlineReminderTime);
      });

      test('should create command for task completion', () {
        // Arrange
        const taskId = 'existing-task-123';
        const title = 'Completed Task';

        // Act
        final command = SaveTaskCommand(
          id: taskId,
          title: title,
          isCompleted: true,
        );

        // Assert
        expect(command.id, taskId);
        expect(command.title, title);
        expect(command.isCompleted, true);
      });

      test('should create command with priority and estimated time', () {
        // Arrange
        const title = 'Prioritized Task';
        const priority = EisenhowerPriority.urgentImportant;
        const estimatedTime = 120; // 2 hours

        // Act
        final command = SaveTaskCommand(
          title: title,
          priority: priority,
          estimatedTime: estimatedTime,
        );

        // Assert
        expect(command.title, title);
        expect(command.priority, priority);
        expect(command.estimatedTime, estimatedTime);
      });

      test('should create command with parent task and order', () {
        // Arrange
        const title = 'Subtask';
        const parentTaskId = 'parent-task-456';
        const order = 2.5;

        // Act
        final command = SaveTaskCommand(
          title: title,
          parentTaskId: parentTaskId,
          order: order,
        );

        // Assert
        expect(command.title, title);
        expect(command.parentTaskId, parentTaskId);
        expect(command.order, order);
      });

      test('should create command with tags', () {
        // Arrange
        const title = 'Tagged Task';
        final tagIds = ['tag-1', 'tag-2', 'tag-3'];

        // Act
        final command = SaveTaskCommand(
          title: title,
          tagIdsToAdd: tagIds,
        );

        // Assert
        expect(command.title, title);
        expect(command.tagIdsToAdd, tagIds);
      });
    });

    group('Response Creation', () {
      test('should create response with required properties', () {
        // Arrange
        const id = 'task-123';
        final createdDate = DateTime.now().toUtc();
        final modifiedDate = DateTime.now().toUtc();

        // Act
        final response = SaveTaskCommandResponse(
          id: id,
          createdDate: createdDate,
          modifiedDate: modifiedDate,
        );

        // Assert
        expect(response.id, id);
        expect(response.createdDate, createdDate);
        expect(response.modifiedDate, modifiedDate);
      });

      test('should create response without modified date', () {
        // Arrange
        const id = 'new-task-456';
        final createdDate = DateTime.now().toUtc();

        // Act
        final response = SaveTaskCommandResponse(
          id: id,
          createdDate: createdDate,
        );

        // Assert
        expect(response.id, id);
        expect(response.createdDate, createdDate);
        expect(response.modifiedDate, isNull);
      });
    });

    group('Date Conversion', () {
      test('should convert local dates to UTC', () {
        // Arrange
        const title = 'Task with Local Dates';
        final localPlannedDate = DateTime(2024, 1, 15, 10, 30); // Local time
        final localDeadlineDate = DateTime(2024, 1, 20, 15, 45); // Local time

        // Act
        final command = SaveTaskCommand(
          title: title,
          plannedDate: localPlannedDate,
          deadlineDate: localDeadlineDate,
        );

        // Assert
        expect(command.title, title);
        expect(command.plannedDate?.isUtc, isTrue);
        expect(command.deadlineDate?.isUtc, isTrue);
        // Note: Don't assert exact day match due to timezone conversions
        expect(command.plannedDate, isNotNull);
        expect(command.deadlineDate, isNotNull);
      });

      test('should convert recurrence dates to UTC', () {
        // Arrange
        const title = 'Recurring Task with Local Dates';
        final localStartDate = DateTime(2024, 1, 1, 9, 0); // Local time
        final localEndDate = DateTime(2024, 12, 31, 18, 0); // Local time

        // Act
        final command = SaveTaskCommand(
          title: title,
          recurrenceType: RecurrenceType.daily,
          recurrenceStartDate: localStartDate,
          recurrenceEndDate: localEndDate,
        );

        // Assert
        expect(command.title, title);
        expect(command.recurrenceStartDate?.isUtc, isTrue);
        expect(command.recurrenceEndDate?.isUtc, isTrue);
        // Note: Don't assert exact day match due to timezone conversions
        expect(command.recurrenceStartDate, isNotNull);
        expect(command.recurrenceEndDate, isNotNull);
      });

      test('should handle null dates gracefully', () {
        // Arrange
        const title = 'Task with No Dates';

        // Act
        final command = SaveTaskCommand(
          title: title,
          plannedDate: null,
          deadlineDate: null,
          recurrenceStartDate: null,
          recurrenceEndDate: null,
        );

        // Assert
        expect(command.title, title);
        expect(command.plannedDate, isNull);
        expect(command.deadlineDate, isNull);
        expect(command.recurrenceStartDate, isNull);
        expect(command.recurrenceEndDate, isNull);
      });
    });
  });
}
