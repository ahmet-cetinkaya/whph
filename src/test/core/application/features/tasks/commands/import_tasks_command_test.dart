import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/import_tasks_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/annotations.dart';
import 'import_tasks_command_test.mocks.dart';

@GenerateMocks([Mediator])
void main() {
  late ImportTasksCommandHandler handler;
  late MockMediator mockMediator;
  late Directory tempDir;

  setUp(() async {
    mockMediator = MockMediator();
    handler = ImportTasksCommandHandler(mockMediator);
    tempDir = await Directory.systemTemp.createTemp('import_tasks_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ImportTasksCommandHandler Generic Tests', () {
    test('should import generic CSV successfully', () async {
      final file = File('${tempDir.path}/tasks.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE\r\n'
        'Task 1,Desc 1,3,2023-10-01,2023-10-02\r\n'
        'Task 2,Desc 2,1,,\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 2);
      expect(response.failureCount, 0);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Task 1')))).called(1);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Task 2')))).called(1);
    });

    test('should handle empty file', () async {
      final file = File('${tempDir.path}/empty.csv');
      await file.writeAsString('');

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 0);
    });
  });

  group('ImportTasksCommandHandler Todoist Tests', () {
    test('should import Todoist CSV successfully with hierarchy', () async {
      final file = File('${tempDir.path}/todoist.csv');
      await file.writeAsString(
        'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,DATE\r\n'
        'task,Parent Task,Parent Desc,1,1,\r\n'
        'task,Child Task,Child Desc,2,2,\r\n'
        'task,Grandchild Task,,3,3,\r\n'
        'task,Sibling Task,,4,1,\r\n',
      );

      // We need to return different IDs to test hierarchy
      var callCount = 0;
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any)).thenAnswer((_) async {
        callCount++;
        return SaveTaskCommandResponse(id: 'task-$callCount', createdDate: DateTime.now());
      });

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 4);
      expect(response.failureCount, 0);

      // Verify Parent
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Parent Task' &&
          cmd.parentTaskId == null &&
          cmd.priority == EisenhowerPriority.urgentImportant)))).called(1);

      // Verify Child (should have Parent Task ID as parent)
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Child Task' &&
          cmd.parentTaskId == 'task-1' &&
          cmd.priority == EisenhowerPriority.urgentNotImportant)))).called(1);

      // Verify Grandchild (should have Child Task ID as parent)
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Grandchild Task' &&
          cmd.parentTaskId == 'task-2' &&
          cmd.priority == EisenhowerPriority.notUrgentImportant)))).called(1);

      // Verify Sibling (should have null parent)
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Sibling Task' &&
          cmd.parentTaskId == null &&
          cmd.priority == EisenhowerPriority.notUrgentNotImportant)))).called(1);
    });

    test('should skip non-task rows in Todoist CSV', () async {
      final file = File('${tempDir.path}/todoist_mixed.csv');
      await file.writeAsString(
        'TYPE,CONTENT,PRIORITY,INDENT\r\n'
        'task,Task 1,1,1\r\n'
        'section,Section 1,1,1\r\n'
        'note,Note 1,1,1\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 1);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any)).called(1);
    });

    test('should handle missing columns by using default indices', () async {
      final file = File('${tempDir.path}/todoist_minimal.csv');
      await file.writeAsString(
        'CONTENT,PRIORITY\r\n'
        'Minimal Task,1\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 1);
    });
  });
}
