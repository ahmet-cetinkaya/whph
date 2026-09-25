import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_transfer_file_store.dart';

final class McpDataTransferService implements IMcpDataTransferService {
  const McpDataTransferService({
    required Mediator mediator,
    required ICompressionService compressionService,
    required ITimerSessionService timerSessionService,
    required IMcpOperationService operationService,
    required McpTransferFileStore fileStore,
    required AppDatabase database,
    required Future<void> Function() reloadApplicationState,
  })  : _mediator = mediator,
        _compressionService = compressionService,
        _timerSessionService = timerSessionService,
        _operationService = operationService,
        _fileStore = fileStore,
        _database = database,
        _reloadApplicationState = reloadApplicationState;

  final Mediator _mediator;
  final ICompressionService _compressionService;
  final ITimerSessionService _timerSessionService;
  final IMcpOperationService _operationService;
  final McpTransferFileStore _fileStore;
  final AppDatabase _database;
  final Future<void> Function() _reloadApplicationState;

  @override
  Future<McpTransferArtifact> exportData({
    required String clientGrantId,
    required McpDataExportFormat format,
  }) async {
    final response =
        await _mediator.send<ExportDataCommand, ExportDataCommandResponse>(ExportDataCommand(switch (format) {
      McpDataExportFormat.json => ExportDataFileOptions.json,
      McpDataExportFormat.csv => ExportDataFileOptions.csv,
      McpDataExportFormat.whph => ExportDataFileOptions.backup,
    }));
    return _fileStore.storeExport(
      clientGrantId: clientGrantId,
      fileName: response.fileName,
      fileExtension: response.fileExtension,
      content: response.fileContent,
    );
  }

  @override
  Future<McpOperation> prepareImport({
    required String clientGrantId,
    required Set<String> currentScopes,
    required String sourceName,
    required McpDataImportStrategy strategy,
  }) async {
    late McpStagedImport staged;
    try {
      staged = await _fileStore.stageImport(
        clientGrantId: clientGrantId,
        sourceName: sourceName,
      );
    } on McpTransferSourceMissingException {
      throw const McpDataTransferException(
        McpDataTransferFailure.permissionRequired,
        'Place the selected WHPH file in the configured transfer directory.',
      );
    } on ArgumentError {
      throw const McpDataTransferException(
        McpDataTransferFailure.invalidInput,
        'The import identifier must be a file basename.',
      );
    } on FileSystemException catch (error) {
      throw McpDataTransferException(
        error.message.contains('Too many') || error.message.contains('exceeds')
            ? McpDataTransferFailure.limitExceeded
            : McpDataTransferFailure.invalidInput,
        'The import source was rejected.',
      );
    }
    try {
      await _fileStore.validateWhphEnvelopeAndSize(staged);
      final importData = await _readImportDocument(staged);
      final requiredScopes = _requiredImportScopes(importData, strategy);
      if (!currentScopes.containsAll(requiredScopes)) {
        throw const McpDataTransferException(
          McpDataTransferFailure.permissionDenied,
          'The connection lacks a scope required by this backup.',
        );
      }
      final requestHash = sha256.convert(utf8.encode('$clientGrantId:${staged.sha256}:${strategy.name}')).toString();
      return await _operationService.prepare(
        clientGrantId: clientGrantId,
        type: McpOperationType.dataImport,
        requiredScopes: requiredScopes,
        requestHash: requestHash,
        summary: '${strategy.name} WHPH backup (${staged.sizeBytes} bytes)',
        execute: () => _executeImport(staged, strategy),
      );
    } on McpDataTransferException {
      await _fileStore.removeStaged(staged);
      rethrow;
    } on FormatException {
      await _fileStore.removeStaged(staged);
      throw const McpDataTransferException(
        McpDataTransferFailure.invalidInput,
        'The staged WHPH backup is invalid.',
      );
    } catch (_) {
      await _fileStore.removeStaged(staged);
      rethrow;
    }
  }

  @override
  Future<McpArtifactChunk?> readArtifactChunk({
    required String clientGrantId,
    required String artifactId,
    required int offset,
    int length = mcpMaximumArtifactChunkBytes,
  }) =>
      _fileStore.readArtifactChunk(
        clientGrantId: clientGrantId,
        artifactId: artifactId,
        offset: offset,
        length: length,
      );

  Future<Map<String, dynamic>> _readImportDocument(McpStagedImport staged) async {
    final bytes = await _fileStore.readStaged(staged);
    final jsonText = await _compressionService.extractFromWhphFile(Uint8List.fromList(bytes));
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic> || decoded['appInfo'] is! Map) {
      throw const FormatException('Invalid WHPH data document');
    }
    return Map.unmodifiable(decoded);
  }

  Set<String> _requiredImportScopes(
    Map<String, dynamic> document,
    McpDataImportStrategy strategy,
  ) {
    if (strategy == McpDataImportStrategy.replace) {
      return const {
        McpScopes.dataImport,
        McpScopes.tasksWrite,
        McpScopes.tasksDelete,
        McpScopes.habitsWrite,
        McpScopes.habitsDelete,
        McpScopes.notesWrite,
        McpScopes.notesDelete,
        McpScopes.tagsWrite,
        McpScopes.tagsDelete,
        McpScopes.usageWrite,
        McpScopes.usageDelete,
        McpScopes.settingsWrite,
        McpScopes.syncManage,
      };
    }
    final scopes = <String>{McpScopes.dataImport};
    void include(
      String writeScope,
      Iterable<String> keys, {
      String? deleteScope,
    }) {
      for (final key in keys) {
        final items = document[key];
        if (items is! List) continue;
        if (items.isNotEmpty) scopes.add(writeScope);
        if (deleteScope != null && items.any((item) => item is Map && item['deletedDate'] != null)) {
          scopes.add(deleteScope);
        }
      }
    }

    include(McpScopes.tasksWrite, const ['tasks', 'taskStatuses', 'taskTags', 'taskTimeRecords'],
        deleteScope: McpScopes.tasksDelete);
    include(McpScopes.habitsWrite, const ['habits', 'habitRecords', 'habitTags', 'habitTimeRecords'],
        deleteScope: McpScopes.habitsDelete);
    include(McpScopes.notesWrite, const ['notes', 'noteTags'], deleteScope: McpScopes.notesDelete);
    include(
        McpScopes.tagsWrite,
        const [
          'tags',
          'tagTags',
          'taskTags',
          'habitTags',
          'noteTags',
          'appUsageTags',
        ],
        deleteScope: McpScopes.tagsDelete);
    include(
        McpScopes.usageWrite,
        const [
          'appUsages',
          'appUsageTags',
          'appUsageTimeRecords',
          'appUsageTagRules',
          'appUsageIgnoreRules',
        ],
        deleteScope: McpScopes.usageDelete);
    include(McpScopes.settingsWrite, const ['settings']);
    include(McpScopes.syncManage, const ['syncDevices']);
    return Set.unmodifiable(scopes);
  }

  Future<McpOperationResult> _executeImport(
    McpStagedImport staged,
    McpDataImportStrategy strategy,
  ) async {
    try {
      if (!await _fileStore.verifyStaged(staged)) {
        throw const FormatException('Staged import changed after approval');
      }
      for (final timer in _timerSessionService.list()) {
        await _timerSessionService.stop(timer.sessionId);
      }
      await _database.restoreBarrier.runExclusive(() async {
        await _database.createRestoreSnapshot();
        if (!await _fileStore.verifyStaged(staged)) {
          throw const FormatException('Staged import changed before commit');
        }
        final bytes = await _fileStore.readStaged(staged);
        await _mediator.send<ImportDataCommand, ImportDataCommandResponse>(
          ImportDataCommand(
            Uint8List.fromList(bytes),
            switch (strategy) {
              McpDataImportStrategy.merge => ImportStrategy.merge,
              McpDataImportStrategy.replace => ImportStrategy.replace,
            },
          ),
        );
      });
      await _reloadApplicationState();
      return McpOperationResult({
        'strategy': strategy.name,
        'imported': true,
      });
    } finally {
      await _fileStore.removeStaged(staged);
    }
  }
}
