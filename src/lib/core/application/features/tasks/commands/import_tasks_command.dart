import 'dart:io';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:csv/csv.dart';
import 'package:acore/acore.dart';

enum TaskImportType {
  generic,
  todoist,
}

/// Maximum file size for CSV import (10MB)
const int _maxFileSizeBytes = 10 * 1024 * 1024;

/// Maximum number of errors to collect during import
const int _maxErrorCount = 100;

/// Error ID constants for CSV import
class ImportErrorIds {
  static const String fileReadError = 'task_import_file_read_error';
  static const String csvParseError = 'task_import_csv_parse_error';
  static const String missingRequiredColumn = 'task_import_missing_required_column';
  static const String mediatorError = 'task_import_mediator_error';
  static const String invalidFilePath = 'task_import_invalid_file_path';
  static const String dateParseError = 'task_import_date_parse_error';
}

/// Error message constants for CSV import
class ImportErrorMessages {
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
      throw ArgumentError(ImportErrorMessages.negativeCount);
    }
    if (failureCount < 0) {
      throw ArgumentError(ImportErrorMessages.negativeCount);
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
      throw ArgumentError(ImportErrorMessages.emptyFilePath);
    }
  }
}

class ImportTasksCommandHandler implements IRequestHandler<ImportTasksCommand, ImportTasksCommandResponse> {
  final Mediator _mediator;

  ImportTasksCommandHandler(this._mediator);

  /// Cache for resolved tag IDs during a single import run
  /// Key: normalized tag name (lowercase), Value: tag ID
  final Map<String, String> _tagIdCache = {};

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
        errors: ['${ImportErrorMessages.fileNotFound}: ${request.filePath}'],
      );
    }

    // Check file size
    try {
      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        return ImportTasksCommandResponse(
          successCount: 0,
          failureCount: 1,
          errors: [ImportErrorMessages.fileTooLarge],
        );
      }
    } on FileSystemException catch (e, stackTrace) {
      Logger.error(
        '[${ImportErrorIds.fileReadError}] ${ImportErrorMessages.fileReadError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${ImportErrorMessages.fileReadError}: ${e.message}'],
      );
    }

    // Read file content with error handling
    final String input;
    try {
      input = await file.readAsString();
    } on FileSystemException catch (e, stackTrace) {
      Logger.error(
        '[${ImportErrorIds.fileReadError}] ${ImportErrorMessages.fileReadError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${ImportErrorMessages.fileReadError}: ${e.message}'],
      );
    } on Exception catch (e, stackTrace) {
      Logger.error(
        '[${ImportErrorIds.fileReadError}] ${ImportErrorMessages.fileReadError}: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${ImportErrorMessages.fileReadError}: $e'],
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
        '[${ImportErrorIds.csvParseError}] ${ImportErrorMessages.csvParseError}: ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${ImportErrorMessages.csvParseError}: ${e.message}'],
      );
    } on Exception catch (e, stackTrace) {
      Logger.error(
        '[${ImportErrorIds.csvParseError}] ${ImportErrorMessages.csvParseError}: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return ImportTasksCommandResponse(
        successCount: 0,
        failureCount: 1,
        errors: ['${ImportErrorMessages.csvParseError}: $e'],
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

        final SaveTaskCommand? saveCommand = await _mapRowToSaveCommand(row, request.importType, colIndices, parentId);
        if (saveCommand != null) {
          final response = await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
          parentIdsByIndent[indent] = response.id;
          successCount++;
        }
      } on FormatException catch (e, stackTrace) {
        // Data format errors in CSV row
        failureCount++;
        final errorMsg = 'Row ${i + 2}: Invalid data format - ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${ImportErrorIds.dateParseError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on ArgumentError catch (e, stackTrace) {
        // Invalid argument errors (e.g., invalid column values)
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${ImportErrorIds.missingRequiredColumn}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on StateError catch (e, stackTrace) {
        // State errors from mediator
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${ImportErrorMessages.mediatorError} - ${e.message}';
        _addError(errors, errorMsg);
        Logger.error(
          '[${ImportErrorIds.mediatorError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } on Exception catch (e, stackTrace) {
        // Known exceptions during row import
        failureCount++;
        final errorMsg = 'Row ${i + 2}: ${ImportErrorMessages.rowImportError} - $e';
        _addError(errors, errorMsg);
        Logger.error(
          '[${ImportErrorIds.mediatorError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );
      } catch (e, stackTrace) {
        // Don't catch Exception - let truly unexpected errors propagate
        // Only catch specific exceptions we know how to handle
        failureCount++;
        final errorMsg = 'Row ${i + 2}: Unexpected error - ${e.runtimeType}: $e';
        _addError(errors, errorMsg);
        Logger.error(
          '[${ImportErrorIds.mediatorError}] $errorMsg',
          error: e,
          stackTrace: stackTrace,
        );

        // Rethrow programming errors that should fail fast
        if (e is NoSuchMethodError || e is TypeError) {
          rethrow;
        }
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
      return ImportErrorMessages.emptyFilePath;
    }

    final normalizedPath = filePath.replaceAll('\\', '/');
    if (normalizedPath.contains('../') || normalizedPath.contains('..\\') || normalizedPath.startsWith('..')) {
      Logger.error(
        '[${ImportErrorIds.invalidFilePath}] Path traversal attempt detected: $filePath',
      );
      return ImportErrorMessages.invalidFilePath;
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
        'LABELS': header.indexOf('LABELS'),
      };
    }
    return {
      'CONTENT': header.indexOf('TITLE'),
      'DESCRIPTION': header.indexOf('DESCRIPTION'),
      'PRIORITY': header.indexOf('PRIORITY'),
      'PLANNED_DATE': header.indexOf('PLANNED_DATE'),
      'DEADLINE_DATE': header.indexOf('DEADLINE_DATE'),
      'TAGS': header.indexOf('TAGS'),
    };
  }

  int _getIndent(List<dynamic> row, int? index, TaskImportType type) {
    if (type != TaskImportType.todoist || index == null || index < 0 || index >= row.length) {
      return 1;
    }
    return int.tryParse(row[index].toString()) ?? 1;
  }

  Future<SaveTaskCommand?> _mapRowToSaveCommand(
      List<dynamic> row, TaskImportType type, Map<String, int> colIndices, String? parentId) async {
    if (type == TaskImportType.todoist) {
      return await _mapTodoistRow(row, colIndices, parentId);
    } else {
      return await _mapGenericRow(row, colIndices);
    }
  }

  Future<SaveTaskCommand?> _mapTodoistRow(List<dynamic> row, Map<String, int> idx, String? parentId) async {
    final typeIdx = idx['TYPE'];
    if (typeIdx != null && typeIdx >= 0 && typeIdx < row.length) {
      if (row[typeIdx].toString().toLowerCase() != 'task') return null;
    }

    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw ArgumentError("Required column 'CONTENT' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final content = row[contentIdx].toString();
    if (content.isEmpty) return null;

    // Handle tags in content (Todoist style: @tag)
    final contentTags = _extractTodoistTags(content);
    final title = _cleanTodoistTitle(content);

    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length) ? row[descIdx]?.toString() : null;

    final labelsIdx = idx['LABELS'];
    final labels = (labelsIdx != null && labelsIdx >= 0 && labelsIdx < row.length) ? row[labelsIdx]?.toString() : null;

    final combinedTags = <String>{...contentTags};
    if (labels != null && labels.isNotEmpty) {
      combinedTags.addAll(labels.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    final tagIds = await _getOrCreateTagIds(combinedTags.join(','));

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
      tagIdsToAdd: tagIds,
    );
  }

  List<String> _extractTodoistTags(String content) {
    // Match @tags but exclude trailing punctuation (comma, period, semicolon, colon, etc.)
    // Use word boundary and trailing punctuation strip
    final tagRegex = RegExp(r'@(\w+)');
    final tags = tagRegex.allMatches(content).map((m) => m.group(1)!).toList();
    // Strip any trailing punctuation that might have been captured
    return tags.map((t) => t.replaceAll(RegExp(r'[.,;:!?\)\]\}]+$'), '')).toList();
  }

  String _cleanTodoistTitle(String content) {
    return content.replaceAll(RegExp(r'@(\S+)'), '').trim();
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

  Future<SaveTaskCommand?> _mapGenericRow(List<dynamic> row, Map<String, int> idx) async {
    final contentIdx = idx['CONTENT'];
    if (contentIdx == null || contentIdx < 0) {
      throw ArgumentError("Required column 'TITLE' is missing in CSV header.");
    }
    if (contentIdx >= row.length) return null;
    final title = row[contentIdx].toString();
    if (title.isEmpty) return null;

    final descIdx = idx['DESCRIPTION'];
    final description = (descIdx != null && descIdx >= 0 && descIdx < row.length) ? row[descIdx]?.toString() : null;

    final tagsIdx = idx['TAGS'];
    final tagsString = (tagsIdx != null && tagsIdx >= 0 && tagsIdx < row.length) ? row[tagsIdx]?.toString() : null;
    final tagIds = await _getOrCreateTagIds(tagsString);

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
      tagIdsToAdd: tagIds,
    );
  }

  Future<List<String>?> _getOrCreateTagIds(String? tagsString) async {
    if (tagsString == null || tagsString.trim().isEmpty) return null;

    final tags = tagsString.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tags.isEmpty) return null;

    final List<String> tagIds = [];
    for (final tagName in tags) {
      final normalizedTagName = tagName.toLowerCase();

      // Check cache first for existing tag ID
      if (_tagIdCache.containsKey(normalizedTagName)) {
        tagIds.add(_tagIdCache[normalizedTagName]!);
        continue;
      }

      // Search for existing tag
      final query = GetListTagsQuery(
        pageIndex: 0,
        pageSize: 1,
        search: tagName,
      );
      final response = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      // Find exact match using simplified logic
      final existingTag = response.items.cast<TagListItem?>().firstWhere(
            (t) => t!.name.toLowerCase() == normalizedTagName,
            orElse: () => null,
          );

      String? tagId;
      if (existingTag != null) {
        tagId = existingTag.id;
      } else {
        // Create new tag
        final saveResponse = await _mediator.send<SaveTagCommand, SaveTagCommandResponse>(SaveTagCommand(
          name: tagName,
          type: TagType.label,
        ));
        tagId = saveResponse.id;
      }

      // Cache the resolved tag ID
      _tagIdCache[normalizedTagName] = tagId;
      tagIds.add(tagId);
    }

    return tagIds;
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } on FormatException catch (e, stackTrace) {
      Logger.warning(
        '[${ImportErrorIds.dateParseError}] Failed to parse date: "$dateStr" - ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
