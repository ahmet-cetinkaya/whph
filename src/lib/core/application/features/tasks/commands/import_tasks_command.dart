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

    var i = 0;
    for (final row in dataRows) {
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
      i++;
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
    // Use header-based lookup to support flexible column order
    return {
      'CONTENT': header.indexOf('TITLE'),
      'DESCRIPTION': header.indexOf('DESCRIPTION'),
      'PRIORITY': header.indexOf('PRIORITY'),
      'PLANNED_DATE': header.indexOf('PLANNED_DATE'),
      'DEADLINE_DATE': header.indexOf('DEADLINE_DATE'),
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
    // TYPE column: if missing, assume all rows are tasks (don't filter)
    final typeIdx = idx['TYPE'];
    if (typeIdx != null && typeIdx >= 0 && typeIdx < row.length) {
      if (row[typeIdx].toString().toLowerCase() != 'task') return null;
    }

    // CONTENT column is required - throw if missing from header
    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw Exception("Required column 'CONTENT' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final title = row[contentIdx].toString();
    if (title.isEmpty) return null;

    // DESCRIPTION is optional
    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length)
        ? row[descIdx]?.toString()
        : null;

    // PRIORITY: default to 4 (lowest) if column missing
    final priorityIdx = idx['PRIORITY'];
    final priorityValue = (priorityIdx != null && priorityIdx >= 0 && priorityIdx < row.length)
        ? (int.tryParse(row[priorityIdx]?.toString() ?? '') ?? 4)
        : 4;

    final priority = _mapTodoistPriority(priorityValue);

    return SaveTaskCommand(
      title: title,
      description: description,
      priority: priority,
      parentTaskId: parentId,
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
    // CONTENT column is required - throw if missing from header
    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw Exception("Required column 'TITLE' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final title = row[contentIdx].toString();
    if (title.isEmpty) return null;

    // DESCRIPTION is optional
    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length)
        ? row[descIdx]?.toString()
        : null;

    // PRIORITY: optional, default to null if column missing
    EisenhowerPriority? priority;
    final priorityIdx = idx['PRIORITY'];
    if (priorityIdx != null && priorityIdx >= 0 && priorityIdx < row.length) {
      final pVal = int.tryParse(row[priorityIdx].toString());
      if (pVal != null && pVal >= 0 && pVal < EisenhowerPriority.values.length) {
        priority = EisenhowerPriority.values[pVal];
      }
    }

    // PLANNED_DATE: optional
    DateTime? plannedDate;
    final plannedIdx = idx['PLANNED_DATE'];
    if (plannedIdx != null && plannedIdx >= 0 && plannedIdx < row.length) {
      plannedDate = _parseDate(row[plannedIdx].toString());
    }

    // DEADLINE_DATE: optional
    DateTime? deadlineDate;
    final deadlineIdx = idx['DEADLINE_DATE'];
    if (deadlineIdx != null && deadlineIdx >= 0 && deadlineIdx < row.length) {
      deadlineDate = _parseDate(row[deadlineIdx].toString());
    }

    return SaveTaskCommand(
      title: title,
      description: description,
      priority: priority,
      plannedDate: plannedDate,
      deadlineDate: deadlineDate,
    );
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }
}
