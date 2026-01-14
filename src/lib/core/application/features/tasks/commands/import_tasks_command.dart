import 'dart:io';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:csv/csv.dart';

enum TaskImportType {
  generic,
  todoist,
}

class ImportTasksCommandResponse {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  ImportTasksCommandResponse({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });
}

class ImportTasksCommand implements IRequest<ImportTasksCommandResponse> {
  final String filePath;
  final TaskImportType importType;

  ImportTasksCommand({
    required this.filePath,
    required this.importType,
  });
}

class ImportTasksCommandHandler implements IRequestHandler<ImportTasksCommand, ImportTasksCommandResponse> {
  final Mediator _mediator;

  ImportTasksCommandHandler(this._mediator);

  @override
  Future<ImportTasksCommandResponse> call(ImportTasksCommand request) async {
    final file = File(request.filePath);
    if (!await file.exists()) {
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['File not found: ${request.filePath}'],
      );
    }

    final input = await file.readAsString();

    // Detect EOL
    String? eol;
    if (input.contains('\r\n')) {
      eol = '\r\n';
    } else if (input.contains('\n')) {
      eol = '\n';
    }

    final List<List<dynamic>> rows = CsvToListConverter(
      shouldParseNumbers: true,
      allowInvalid: true,
      eol: eol,
    ).convert(input);

    if (rows.isEmpty) {
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 0,
        errors: ['CSV file is empty.'],
      );
    }

    int successCount = 0;
    int failureCount = 0;
    final List<String> errors = [];

    // Find header indices (Todoist may change order)
    final header = rows.first.map((e) => e.toString().toUpperCase()).toList();
    final colIndices = _getColumnIndices(header, request.importType);

    // Track parents for hierarchy (Indent level -> Task ID)
    final Map<int, String> parentIdsByIndent = {};

    // Skip header row
    final dataRows = rows.skip(1);

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows.elementAt(i);
      try {
        final indent = _getIndent(row, colIndices['INDENT'], request.importType);
        final parentId = indent > 1 ? parentIdsByIndent[indent - 1] : null;

        final SaveTaskCommand? saveCommand = _mapRowToSaveCommand(row, request.importType, colIndices, parentId);
        if (saveCommand != null) {
          final response = await _mediator.send(saveCommand) as SaveTaskCommandResponse;
          parentIdsByIndent[indent] = response.id;
          successCount++;
        }
      } catch (e) {
        failureCount++;
        errors.add('Row ${i + 2}: $e');
        Logger.error('Failed to import task at row ${i + 2}: $e');
      }
    }

    return ImportTasksCommandResponse(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }

  Map<String, int> _getColumnIndices(List<String> header, TaskImportType type) {
    if (type == TaskImportType.todoist) {
      return {
        'TYPE': header.indexOf('TYPE'),
        'CONTENT': header.indexOf('CONTENT'),
        'DESCRIPTION': header.indexOf('DESCRIPTION'),
        'PRIORITY': header.indexOf('PRIORITY'),
        'INDENT': header.indexOf('INDENT'),
        'DATE': header.indexOf('DATE'),
      };
    }
    // Generic WHPH format: TITLE, DESCRIPTION, PRIORITY, PLANNED_DATE, DEADLINE_DATE
    return {
      'CONTENT': 0,
      'DESCRIPTION': 1,
      'PRIORITY': 2,
      'PLANNED_DATE': 3,
      'DEADLINE_DATE': 4,
    };
  }

  int _getIndent(List<dynamic> row, int? index, TaskImportType type) {
    if (type != TaskImportType.todoist || index == null || index < 0 || index >= row.length) {
      return 1;
    }
    return int.tryParse(row[index].toString()) ?? 1;
  }

  SaveTaskCommand? _mapRowToSaveCommand(
      List<dynamic> row, TaskImportType type, Map<String, int> colIndices, String? parentId) {
    if (type == TaskImportType.todoist) {
      return _mapTodoistRow(row, colIndices, parentId);
    } else {
      return _mapGenericRow(row, colIndices);
    }
  }

  SaveTaskCommand? _mapTodoistRow(List<dynamic> row, Map<String, int> idx, String? parentId) {
    final typeIdx = idx['TYPE']!;
    if (typeIdx >= 0 && row[typeIdx].toString().toLowerCase() != 'task') return null;

    final title = row[idx['CONTENT']!].toString();
    final description = idx['DESCRIPTION']! >= 0 ? row[idx['DESCRIPTION']!]?.toString() : null;
    final priorityValue = int.tryParse(row[idx['PRIORITY']!]?.toString() ?? '') ?? 4;

    // Todoist 1 (Highest) -> WHPH urgentImportant (3)
    // Todoist 2 -> WHPH urgentNotImportant (1)
    // Todoist 3 -> WHPH notUrgentImportant (2)
    // Todoist 4 -> WHPH notUrgentNotImportant (0)
    final priority = _mapTodoistPriority(priorityValue);

    return SaveTaskCommand(
      title: title,
      description: description,
      priority: priority,
      parentTaskId: parentId,
      // Date parsing would go here if needed
    );
  }

  EisenhowerPriority _mapTodoistPriority(int todoistPriority) {
    switch (todoistPriority) {
      case 1:
        return EisenhowerPriority.urgentImportant;
      case 2:
        return EisenhowerPriority.urgentNotImportant;
      case 3:
        return EisenhowerPriority.notUrgentImportant;
      case 4:
      default:
        return EisenhowerPriority.notUrgentNotImportant;
    }
  }

  SaveTaskCommand? _mapGenericRow(List<dynamic> row, Map<String, int> idx) {
    final title = row[idx['CONTENT']!].toString();
    if (title.isEmpty) return null;

    return SaveTaskCommand(
      title: title,
      description: idx['DESCRIPTION']! < row.length ? row[idx['DESCRIPTION']!]?.toString() : null,
      // Add other fields mapping for generic
    );
  }
}
