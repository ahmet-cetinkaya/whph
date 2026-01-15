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

/// Maximum file size for CSV import (10MB)
const int _maxFileSizeBytes = 10 * 1024 * 1024;

/// Maximum number of errors to collect during import
const int _maxErrorCount = 100;

/// Error ID constants for CSV import
class _ImportErrorIds {
  static const String fileReadError = 'task_import_file_read_error';
  static const String csvParseError = 'task_import_csv_parse_error';
  static const String missingRequiredColumn = 'task_import_missing_required_column';
  static const String mediatorError = 'task_import_mediator_error';
  static const String invalidFilePath = 'task_import_invalid_file_path';
  static const String dateParseError = 'task_import_date_parse_error';
}

/// Error message constants for CSV import
class _ImportErrorMessages {
  static const String fileNotFound = 'File not found';
  static const String fileTooLarge = 'CSV file exceeds maximum size of 10MB';
  static const String fileReadError = 'Failed to read file';
  static const String csvParseError = 'Failed to parse CSV';
  static const String mediatorError = 'Failed to save task';
  static const String rowImportError = 'Failed to import row';
  static const String invalidFilePath = 'Invalid file path';
  static const String negativeCount = 'Count cannot be negative';
  static const String emptyFilePath = 'File path cannot be empty';
}

class ImportTasksCommandResponse {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  ImportTasksCommandResponse({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  }) {
    if (successCount < 0) {
      throw ArgumentError(_ImportErrorMessages.negativeCount);
    }
    if (failureCount < 0) {
      throw ArgumentError(_ImportErrorMessages.negativeCount);
    }
  }

  /// Total number of processed rows
  int get totalCount => successCount + failureCount;

  /// Whether the import had any failures
  bool get hasFailures => failureCount > 0;

  /// Whether the import was completely successful
  bool get isCompleteSuccess => failureCount == 0 && successCount > 0;

  /// Whether the import was a partial success (some rows succeeded)
  bool get isPartialSuccess => successCount > 0 && failureCount > 0;
}

class ImportTasksCommand implements IRequest<ImportTasksCommandResponse> {
  final String filePath;
  final TaskImportType importType;

  ImportTasksCommand({
    required this.filePath,
    required this.importType,
  }) {
    if (filePath.trim().isEmpty) {
      throw ArgumentError(_ImportErrorMessages.emptyFilePath);
    }
  }
}

class ImportTasksCommandHandler implements IRequestHandler<ImportTasksCommand, ImportTasksCommandResponse> {
  final Mediator _mediator;

  ImportTasksCommandHandler(this._mediator);

  @override
  Future<ImportTasksCommandResponse> call(ImportTasksCommand request) async {
    // Validate file path
    final pathValidation = _validateFilePath(request.filePath);
    if (pathValidation != null) {
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: [pathValidation],
      );
    }

    final file = File(request.filePath);
    if (!await file.exists()) {
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.fileNotFound}: ${request.filePath}'],
      );
    }

    // Check file size
    try {
      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        return ImportTasksCommandResponse(
          successCount: 0,
          failureCount: 1,
          errors: [_ImportErrorMessages.fileTooLarge],
        );
      }
    } on FileSystemException catch (e, stackTrace) {
      Logger.error(
        '[${_ImportErrorIds.fileReadError}] ${_ImportErrorMessages.fileReadError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.fileReadError}: ${e.message}'],
      );
    }

    // Read file content with error handling
    final String input;
    try {
      input = await file.readAsString();
    } on FileSystemException catch (e, stackTrace) {
      Logger.error(
        '[${_ImportErrorIds.fileReadError}] ${_ImportErrorMessages.fileReadError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.fileReadError}: ${e.message}'],
      );
    } on Exception catch (e, stackTrace) {
      Logger.error(
        '[${_ImportErrorIds.fileReadError}] ${_ImportErrorMessages.fileReadError}: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.fileReadError}: $e'],
      );
    }

    // Check for empty file before attempting CSV parsing
    if (input.trim().isEmpty) {
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 0,
        errors: ['CSV file is empty.'],
      );
    }

    // Detect EOL
    String? eol;
    if (input.contains('\r\n')) {
      eol = '\r\n';
    } else if (input.contains('\n')) {
      eol = '\n';
    }

    // Parse CSV with error handling
    final List<List<dynamic>> rows;
    try {
      rows = CsvToListConverter(
        shouldParseNumbers: true,
        allowInvalid: false,
        eol: eol,
      ).convert(input);
    } on FormatException catch (e, stackTrace) {
      Logger.error(
        '[${_ImportErrorIds.csvParseError}] ${_ImportErrorMessages.csvParseError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.csvParseError}: ${e.message}'],
      );
    } on Exception catch (e, stackTrace) {
      Logger.error(
        '[${_ImportErrorIds.csvParseError}] ${_ImportErrorMessages.csvParseError}: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${_ImportErrorMessages.csvParseError}: $e'],
      );
    }

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
      } on FormatException catch (e, stackTrace) {
        // Data format errors in CSV row
        failureCount++;
        final errorMsg = 'Row ${i + 2}: Invalid data format - ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${_ImportErrorIds.dateParseError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on ArgumentError catch (e, stackTrace) {
        // Invalid argument errors (e.g., invalid column values)
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${_ImportErrorIds.missingRequiredColumn}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on StateError catch (e, stackTrace) {
        // State errors from mediator
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${_ImportErrorMessages.mediatorError} - ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${_ImportErrorIds.mediatorError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on Exception catch (e, stackTrace) {
        // Other unexpected errors
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${_ImportErrorMessages.rowImportError} - $e';
        _addError(errors, errorMsg);
        Logger.error(
          '[${_ImportErrorIds.mediatorError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      }
      i++;
    }

    return ImportTasksCommandResponse(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }

  /// Validates file path to prevent directory traversal attacks
  String? _validateFilePath(String filePath) {
    if (filePath.trim().isEmpty) {
      return _ImportErrorMessages.emptyFilePath;
    }

    final normalizedPath = filePath.replaceAll('\\', '/');
    if (normalizedPath.contains('../') || normalizedPath.contains('..\\') || normalizedPath.startsWith('..')) {
      Logger.error(
        '[${_ImportErrorIds.invalidFilePath}] Path traversal attempt detected: $filePath',
      );
      return _ImportErrorMessages.invalidFilePath;
    }

    return null;
  }

  /// Adds error to list, enforcing maximum error count
  void _addError(List<String> errors, String error) {
    if (errors.length < _maxErrorCount) {
      errors.add(error);
    } else if (errors.length == _maxErrorCount) {
      errors.add('... (additional errors omitted, max $_maxErrorCount errors shown)');
    }
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
    final typeIdx = idx['TYPE'];
    if (typeIdx != null && typeIdx >= 0 && typeIdx < row.length) {
      if (row[typeIdx].toString().toLowerCase() != 'task') return null;
    }

    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw ArgumentError("Required column 'CONTENT' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final title = row[contentIdx].toString();
    if (title.isEmpty) return null;

    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length) ? row[descIdx]?.toString() : null;

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
    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw ArgumentError("Required column 'TITLE' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final title = row[contentIdx].toString();
    if (title.isEmpty) return null;

    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length) ? row[descIdx]?.toString() : null;

    EisenhowerPriority? priority;
    final priorityIdx = idx['PRIORITY'];
    if (priorityIdx != null && priorityIdx >= 0 && priorityIdx < row.length) {
      final pVal = int.tryParse(row[priorityIdx].toString());
      if (pVal != null && pVal >= 0 && pVal < EisenhowerPriority.values.length) {
        priority = EisenhowerPriority.values[pVal];
      }
    }

    DateTime? plannedDate;
    final plannedIdx = idx['PLANNED_DATE'];
    if (plannedIdx != null && plannedIdx >= 0 && plannedIdx < row.length) {
      plannedDate = _parseDate(row[plannedIdx].toString());
    }

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
    } on FormatException catch (e, stackTrace) {
      Logger.warning(
        '[${_ImportErrorIds.dateParseError}] Failed to parse date: "$dateStr" - ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
