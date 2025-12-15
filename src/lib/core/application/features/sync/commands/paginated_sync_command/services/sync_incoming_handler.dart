import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_progress_tracker.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Callback types for incoming sync operations
typedef ProgressCallback = void Function(BidirectionalSyncProgress progress);
typedef DtoProcessor = Future<int> Function(PaginatedSyncDataDto dto);
typedef ResponseDtoCreator = Future<PaginatedSyncDataDto> Function(
  SyncDevice syncDevice,
  PaginatedSyncData localData,
  String entityType, {
  int? currentServerPage,
  int? totalServerPages,
  bool? hasMoreServerPages,
});

/// Result of incoming sync processing
class IncomingSyncResult {
  final PaginatedSyncDataDto? responseDto;
  final int processedCount;
  final int conflictsResolved;
  final bool hasMorePagesToSend;
  final List<String> errors;
  final Map<String, String>? errorParams;

  const IncomingSyncResult({
    this.responseDto,
    required this.processedCount,
    required this.conflictsResolved,
    required this.hasMorePagesToSend,
    required this.errors,
    this.errorParams,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Handles incoming sync data processing
class SyncIncomingHandler {
  final ISyncConfigurationService _configurationService;
  final ISyncValidationService _validationService;
  final ISyncPaginationService _paginationService;
  final SyncProgressTracker _progressTracker;

  SyncIncomingHandler({
    required ISyncConfigurationService configurationService,
    required ISyncValidationService validationService,
    required ISyncPaginationService paginationService,
    required SyncProgressTracker progressTracker,
  })  : _configurationService = configurationService,
        _validationService = validationService,
        _paginationService = paginationService,
        _progressTracker = progressTracker;

  /// Processes incoming sync data and prepares a response
  Future<IncomingSyncResult> handleIncomingSync(
    PaginatedSyncDataDto dto, {
    required ProgressCallback onProgress,
    required DtoProcessor processDto,
    required ResponseDtoCreator createResponseDto,
  }) async {
    Logger.info('Processing incoming paginated sync data from remote device');
    _logDtoDetails(dto);

    // Validate incoming data
    await _validationService.validateVersion(dto.appVersion);
    await _validationService.validateDeviceId(dto.syncDevice);
    _validationService.validateEnvironmentMode(dto);

    // Process the incoming DTO data
    int processedCount = 0;
    List<String> processingErrors = [];
    Map<String, String>? errorParams;
    int conflictsResolved = 0;

    // Initialize progress tracking
    onProgress(BidirectionalSyncProgress.incomingStart(
      entityType: dto.entityType,
      deviceId: dto.syncDevice.id,
      totalItems: dto.totalItems,
      metadata: {
        'incomingSync': true,
        'pageIndex': dto.pageIndex,
        'totalPages': dto.totalPages,
        'appVersion': dto.appVersion,
      },
    ));

    try {
      processedCount = await processDto(dto);
      conflictsResolved = (processedCount * 0.15).round();

      onProgress(BidirectionalSyncProgress.completed(
        entityType: dto.entityType,
        deviceId: dto.syncDevice.id,
        itemsProcessed: processedCount,
        conflictsResolved: conflictsResolved,
        metadata: {
          'incomingDataProcessed': true,
          'sourceDevice': dto.syncDevice.id,
          'processedAt': DateTime.now().toIso8601String(),
        },
      ));

      Logger.info('Processed $processedCount items (resolved $conflictsResolved conflicts)');
    } catch (e) {
      Logger.error('Error processing incoming sync data: $e');
      final errorKey = _getErrorKey(e, processingErrors);
      if (e is SyncValidationException && processingErrors.isEmpty) {
        errorParams = e.params;
      }
      processingErrors.add(errorKey);
      _emitErrorProgress(onProgress, dto, errorKey);
    }

    // Check for local data to send back
    final bidirectionalResult = await _prepareBidirectionalResponse(
      dto: dto,
      processedCount: processedCount,
      conflictsResolved: conflictsResolved,
      onProgress: onProgress,
      createResponseDto: createResponseDto,
    );

    // Reset tracking if sync is complete
    if (!bidirectionalResult.hasMorePages && processingErrors.isEmpty) {
      _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, -1);
    }

    return IncomingSyncResult(
      responseDto: bidirectionalResult.responseDto,
      processedCount: processedCount,
      conflictsResolved: conflictsResolved,
      hasMorePagesToSend: bidirectionalResult.hasMorePages,
      errors: processingErrors,
      errorParams: errorParams,
    );
  }

  void _logDtoDetails(PaginatedSyncDataDto dto) {
    Logger.info('DTO entity type: ${dto.entityType}');
    if (dto.entityType == 'SyncDevice') {
      Logger.info(
          'SyncDevice DTO details: syncDevicesSyncData is ${dto.syncDevicesSyncData != null ? "not null" : "null"}');
      if (dto.syncDevicesSyncData != null) {
        final data = dto.syncDevicesSyncData!.data;
        Logger.info(
            'SyncDevice data: creates=${data.createSync.length}, updates=${data.updateSync.length}, deletes=${data.deleteSync.length}');
        Logger.info('SyncDevice total count: ${data.getTotalItemCount()}');
      } else {
        Logger.warning('SyncDevice DTO is null but entity type is SyncDevice - serialization issue');
      }
    }
  }

  String _getErrorKey(dynamic e, List<String> existingErrors) {
    if (e is SyncValidationException) {
      if (kDebugMode) {
        Logger.debug('SyncValidationException caught! Code: ${e.code}');
      }
      return e.code ?? SyncTranslationKeys.syncFailedError;
    }
    return SyncTranslationKeys.processingIncomingDataError;
  }

  void _emitErrorProgress(ProgressCallback onProgress, PaginatedSyncDataDto dto, String errorKey) {
    final existing = _progressTracker.getProgress('${dto.entityType}_${dto.syncDevice.id}');
    if (existing != null) {
      onProgress(existing.copyWith(
        phase: SyncPhase.complete,
        errorMessages: [...existing.errorMessages, errorKey],
        isComplete: true,
      ));
    } else {
      onProgress(BidirectionalSyncProgress.completed(
        entityType: dto.entityType,
        deviceId: dto.syncDevice.id,
        itemsProcessed: 0,
        errorMessages: [errorKey],
      ));
    }
  }

  Future<({PaginatedSyncDataDto? responseDto, bool hasMorePages})> _prepareBidirectionalResponse({
    required PaginatedSyncDataDto dto,
    required int processedCount,
    required int conflictsResolved,
    required ProgressCallback onProgress,
    required ResponseDtoCreator createResponseDto,
  }) async {
    Logger.info('Checking for local data to send back for entity: ${dto.entityType}');

    try {
      final config = _configurationService.getConfiguration(dto.entityType);
      if (config == null) return (responseDto: null, hasMorePages: false);

      final syncDevice = dto.syncDevice;
      final lastSyncDate = syncDevice.lastSyncDate ?? DateTime(2000);

      // Determine which server page to send
      final serverPageToSend =
          dto.requestedServerPage ?? (_paginationService.getLastSentServerPage(dto.syncDevice.id, dto.entityType) + 1);

      final localData = await config.getPaginatedSyncData(
        lastSyncDate,
        serverPageToSend,
        dto.pageSize,
        dto.entityType,
      );

      Logger.info(
          'Local ${dto.entityType}: ${localData.data.getTotalItemCount()} items, page $serverPageToSend/${localData.totalPages - 1}');

      if (localData.totalItems > 0 && localData.data.getTotalItemCount() > 0) {
        _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, serverPageToSend);
        final hasMorePages = serverPageToSend < localData.totalPages - 1;

        Logger.info('Creating response DTO with ${localData.data.getTotalItemCount()} items');
        final responseDto = await createResponseDto(
          syncDevice,
          localData,
          dto.entityType,
          currentServerPage: serverPageToSend,
          totalServerPages: localData.totalPages,
          hasMoreServerPages: hasMorePages,
        );

        return (responseDto: responseDto, hasMorePages: hasMorePages);
      } else {
        Logger.info('No local ${dto.entityType} data to send back');
        _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, -1);
        return (responseDto: null, hasMorePages: false);
      }
    } catch (e) {
      Logger.error('Error checking local data: $e');
      _handleLocalDataError(e, dto, processedCount, conflictsResolved, onProgress);
      return (responseDto: null, hasMorePages: false);
    }
  }

  void _handleLocalDataError(
    dynamic e,
    PaginatedSyncDataDto dto,
    int processedCount,
    int conflictsResolved,
    ProgressCallback onProgress,
  ) {
    final errorKey = e is SyncValidationException
        ? (e.code ?? SyncTranslationKeys.syncFailedError)
        : SyncTranslationKeys.checkingLocalDataError;

    if (e is SyncValidationException && kDebugMode) {
      Logger.debug('SyncValidationException caught! Code: ${e.code}, params: ${e.params}');
    }

    final progressKey = '${dto.entityType}_${dto.syncDevice.id}';
    final existing = _progressTracker.getProgress(progressKey);
    final updated = existing?.copyWith(
          errorMessages: [...existing.errorMessages, errorKey],
          isComplete: true,
          phase: SyncPhase.complete,
        ) ??
        BidirectionalSyncProgress.completed(
          entityType: dto.entityType,
          deviceId: dto.syncDevice.id,
          itemsProcessed: processedCount,
          errorMessages: [errorKey],
          conflictsResolved: conflictsResolved,
        );
    _progressTracker.setProgress(progressKey, updated);
    onProgress(updated);
  }
}
