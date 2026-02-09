import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/import_tasks_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/annotations.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
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
      reset(mockMediator);
      final file = File('${tempDir.path}/tasks.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE\r\n'
        'Task 1,Desc 1,3,2023-10-01,2023-10-02\r\n'
        'Task 2,Desc 2,1,,\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
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

    test('should map expanded fields in generic CSV successfully', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/generic_expanded.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE\n'
        'Task 1,Desc 1,0,2024-01-01,2024-01-02\n'
        'Task 2,Desc 2,3,2024-12-31,2025-01-01\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 2);

      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Task 1' &&
          cmd.priority == EisenhowerPriority.notUrgentNotImportant &&
          cmd.plannedDate == DateTime.parse('2024-01-01').toUtc() &&
          cmd.deadlineDate == DateTime.parse('2024-01-02').toUtc())))).called(1);

      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Task 2' &&
          cmd.priority == EisenhowerPriority.urgentImportant &&
          cmd.plannedDate == DateTime.parse('2024-12-31').toUtc() &&
          cmd.deadlineDate == DateTime.parse('2025-01-01').toUtc())))).called(1);
    });

    test('should handle invalid dates and priorities in generic CSV mapping', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/generic_invalid.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE\n'
        'Invalid Date,Desc,1,not-a-date,2024-01-01\n'
        'Invalid Priority,Desc,99,2024-01-01,\n'
        'Non-int Priority,Desc,abc,2024-01-01,\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 3);
      // Invalid date should be null
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>(
          (cmd) => cmd.title == 'Invalid Date' && cmd.plannedDate == null && cmd.deadlineDate != null)))).called(1);
      // Invalid priority should be null
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Invalid Priority' && cmd.priority == null))))
          .called(1);
      // Non-int priority should be null
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Non-int Priority' && cmd.priority == null))))
          .called(1);
    });

    test('should handle empty file', () async {
      reset(mockMediator);
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
      reset(mockMediator);
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
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand)))).thenAnswer((_) async {
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
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_mixed.csv');
      await file.writeAsString(
        'TYPE,CONTENT,PRIORITY,INDENT\r\n'
        'task,Task 1,1,1\r\n'
        'section,Section 1,1,1\r\n'
        'note,Note 1,1,1\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 1);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand)))).called(1);
    });

    test('should handle mixed hierarchy and invalid priorities in Todoist CSV', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_edge.csv');
      await file.writeAsString(
        'TYPE,CONTENT,PRIORITY,INDENT\n'
        'task,Root Task,1,1\n'
        'task,Invalid Priority,abc,2\n'
        'task,Out of Range Priority,99,2\n',
      );

      var callCount = 0;
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand)))).thenAnswer((_) async {
        callCount++;
        return SaveTaskCommandResponse(id: 'task-$callCount', createdDate: DateTime.now());
      });

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 3);
      // Invalid/Out of range priority should map to Not Urgent/Not Important (WHPH default for unknown)
      // Actually Todoist parser defaults to 4 (lowest) if invalid, which is EisenhowerPriority.notUrgentNotImportant
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>(
          (cmd) => cmd.title == 'Root Task' && cmd.priority == EisenhowerPriority.urgentImportant)))).called(1);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>(
              (cmd) => cmd.title == 'Invalid Priority' && cmd.priority == EisenhowerPriority.notUrgentNotImportant))))
          .called(1);
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
              cmd.title == 'Out of Range Priority' && cmd.priority == EisenhowerPriority.notUrgentNotImportant))))
          .called(1);
    });

    test('should handle non-sequential indents in Todoist CSV hierarchy', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_indents.csv');
      await file.writeAsString(
        'TYPE,CONTENT,INDENT\n'
        'task,Root 1,1\n'
        'task,Jump to 3,3\n'
        'task,Back to 2,2\n',
      );

      var callCount = 0;
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand)))).thenAnswer((_) async {
        callCount++;
        return SaveTaskCommandResponse(id: 'task-$callCount', createdDate: DateTime.now());
      });

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 3);
      // Jump to 3: if 2 is missing, it should probably pick the last root or last valid parent.
      // Verification
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Root 1' && cmd.parentTaskId == null)))).called(1);

      // Jump to 3 should have parentTaskId = _parentsStack[1] (which is null if indent 2 was skipped but indent 1 was Root 1)
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Jump to 3' && cmd.parentTaskId == null))))
          .called(1);

      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((cmd) => cmd.title == 'Back to 2' && cmd.parentTaskId == 'task-1'))))
          .called(1);
    });

    test('should handle missing columns by using default indices', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_minimal.csv');
      await file.writeAsString(
        'CONTENT,PRIORITY\r\n'
        'Minimal Task,1\r\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 1);
    });

    test('should import Todoist CSV with labels and content tags', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_tags.csv');
      await file.writeAsString(
        'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,LABELS\r\n'
        'task,Task with @tag1,Desc 1,1,1,"tag2, tag3"\r\n',
      );

      // Mock tag search (None found initially)
      when(mockMediator.send<GetListTagsQuery, GetListTagsQueryResponse>(
              argThat(predicate<GetListTagsQuery>((r) => r is GetListTagsQuery))))
          .thenAnswer((_) async => GetListTagsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((r) => r is SaveTagCommand)))).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as SaveTagCommand;
        return SaveTagCommandResponse(id: 'new-tag-id-${request.name}', createdDate: DateTime.now());
      });

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 1);

      // Verify SaveTaskCommand was sent with correct tags
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Task with' &&
          cmd.tagIdsToAdd != null &&
          cmd.tagIdsToAdd!.length == 3 &&
          cmd.tagIdsToAdd!.any((id) => id.contains('tag1')) &&
          cmd.tagIdsToAdd!.any((id) => id.contains('tag2')) &&
          cmd.tagIdsToAdd!.any((id) => id.contains('tag3')))))).called(1);

      // Verify SaveTagCommands were sent
      verify(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((SaveTagCommand c) => c.name == 'tag1')))).called(1);
      verify(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((SaveTagCommand c) => c.name == 'tag2')))).called(1);
      verify(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((SaveTagCommand c) => c.name == 'tag3')))).called(1);
    });
  });

  group('ImportTasksCommandHandler Tag Tests', () {
    test('should import generic CSV with tags column', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/generic_tags.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE,TAGS\n'
        'Task 1,Desc 1,1,,,"tag1, tag2"\n',
      );

      when(mockMediator.send<GetListTagsQuery, GetListTagsQueryResponse>(
              argThat(predicate<GetListTagsQuery>((r) => r is GetListTagsQuery))))
          .thenAnswer((_) async => GetListTagsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((r) => r is SaveTagCommand)))).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as SaveTagCommand;
        return SaveTagCommandResponse(id: 'new-tag-id-${request.name}', createdDate: DateTime.now());
      });

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 1);

      // Verify SaveTaskCommand was sent with correct tags
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) =>
          cmd.title == 'Task 1' &&
          cmd.tagIdsToAdd != null &&
          cmd.tagIdsToAdd!.length == 2 &&
          cmd.tagIdsToAdd!.any((id) => id.contains('tag1')) &&
          cmd.tagIdsToAdd!.any((id) => id.contains('tag2')))))).called(1);

      verify(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((SaveTagCommand c) => c.name == 'tag1')))).called(1);
      verify(mockMediator.send<SaveTagCommand, SaveTagCommandResponse>(
          argThat(predicate<SaveTagCommand>((SaveTagCommand c) => c.name == 'tag2')))).called(1);
    });
  });

  group('ImportTasksCommandHandler Error Handling Tests', () {
    test('should handle file not found error', () async {
      reset(mockMediator);
      final response = await handler.call(ImportTasksCommand(
        filePath: '/nonexistent/path/to/file.csv',
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 1);
      expect(response.errors.first, contains('File not found'));
    });

    test('should handle mediator exception during task save', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/mediator_error.csv');
      await file.writeAsString(
        'TITLE,DESCRIPTION\n'
        'Task 1,Desc 1\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand)))).thenThrow(Exception('Mediator error'));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 1);
    });

    test('should handle missing CONTENT column in generic CSV', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/missing_content.csv');
      await file.writeAsString(
        'DESCRIPTION,PRIORITY\n'
        'Desc 1,1\n',
      );

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 1);
      expect(response.errors.first, contains("Required column 'TITLE' is missing"));
    });

    test('should handle missing CONTENT column in Todoist CSV', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/todoist_missing_content.csv');
      await file.writeAsString(
        'TYPE,PRIORITY,INDENT\n'
        'task,1,1\n',
      );

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.todoist,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 1);
      expect(response.errors.first, contains("Required column 'CONTENT' is missing"));
    });

    test('should reject empty file path in constructor', () {
      expect(
        () => ImportTasksCommand(filePath: '', importType: TaskImportType.generic),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject file path with only whitespace in constructor', () {
      expect(
        () => ImportTasksCommand(filePath: '   ', importType: TaskImportType.generic),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject negative success count in response', () {
      expect(
        () => ImportTasksCommandResponse(successCount: -1, failureCount: 0, errors: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject negative failure count in response', () {
      expect(
        () => ImportTasksCommandResponse(successCount: 0, failureCount: -1, errors: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should detect path traversal in file path', () async {
      reset(mockMediator);
      final response = await handler.call(ImportTasksCommand(
        filePath: '../../../etc/passwd',
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 0);
      expect(response.failureCount, 1);
      expect(response.errors.first, 'Invalid file path');
    });

    test('should bound error list to maximum 100 errors', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/many_errors.csv');
      final rows = ['TITLE,DESCRIPTION'] + List.generate(150, (i) => 'Task $i,Desc $i,invalid_date');
      await file.writeAsString(rows.join('\n'));

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.errors.length, lessThanOrEqualTo(101));
      if (response.errors.length > 100) {
        expect(response.errors.last, contains('additional errors omitted'));
      }
    });
  });

  group('ImportTasksCommandHandler Bug Fixes', () {
    test('Issue #232: Should import string priorities and common date formats', () async {
      reset(mockMediator);
      final file = File('${tempDir.path}/issue_232.csv');
      // Simulate user input with string priorities and slash-formatted dates
      await file.writeAsString(
        'TITLE,DESCRIPTION,PRIORITY,PLANNED_DATE,DEADLINE_DATE\n'
        'Task String Priority,Desc 1,Urgent,2023-10-01,2023-10-02\n'
        'Task Slash Date,Desc 2,1,2023/10/01,2023/10/02\n'
        'Task Both Issues,Desc 3,Important,2023/10/01,2023/10/02\n',
      );

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
              argThat(predicate<SaveTaskCommand>((r) => r is SaveTaskCommand))))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: 'task-id', createdDate: DateTime.now()));

      final response = await handler.call(ImportTasksCommand(
        filePath: file.path,
        importType: TaskImportType.generic,
      ));

      expect(response.successCount, 3);

      // Verify Task 1: String Priority "Urgent" -> EisenhowerPriority.urgentNotImportant
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) {
        if (cmd.title != 'Task String Priority') return false;
        // "Urgent" should map to 1 (UrgentNotImportant)
        return cmd.priority == EisenhowerPriority.urgentNotImportant;
      })))).called(1);

      // Verify Task 2: Slash Date "2023/10/01" -> DateTime(2023, 10, 1)
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) {
        if (cmd.title != 'Task Slash Date') return false;
        return cmd.plannedDate == DateTime(2023, 10, 1).toUtc() && cmd.deadlineDate == DateTime(2023, 10, 2).toUtc();
      })))).called(1);

      // Verify Task 3: Both
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(predicate<SaveTaskCommand>((cmd) {
        if (cmd.title != 'Task Both Issues') return false;
        return cmd.priority == EisenhowerPriority.notUrgentImportant && // "Important" -> 2
            cmd.plannedDate == DateTime(2023, 10, 1).toUtc();
      })))).called(1);
    });
  });
}
