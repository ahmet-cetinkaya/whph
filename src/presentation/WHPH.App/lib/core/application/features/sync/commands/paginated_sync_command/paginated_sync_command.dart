import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_page_accumulator.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_response_builder.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_progress_tracker.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_device_coordinator.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_device_orchestrator.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_incoming_handler.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_outgoing_handler.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';

class PaginatedSyncCommand implements IRequest<PaginatedSyncCommandResponse> {
  final PaginatedSyncDataDto? paginatedSyncDataDto;
  final String? targetDeviceId;

  PaginatedSyncCommand({this.paginatedSyncDataDto, this.targetDeviceId});
}

@jsonSerializable
class PaginatedSyncCommandResponse {
  final PaginatedSyncDataDto? paginatedSyncDataDto;
  final bool isComplete;
  final String? nextEntityType;
  final int? nextPageIndex;
  final int syncedDeviceCount;
  final bool hadMeaningfulSync;
  final bool hasErrors;
  final List<String> errorMessages;
  final Map<String, String>? errorParams;

  PaginatedSyncCommandResponse({
    this.paginatedSyncDataDto,
    this.isComplete = false,
    this.nextEntityType,
    this.nextPageIndex,
    this.syncedDeviceCount = 0,
    this.hadMeaningfulSync = false,
    this.hasErrors = false,
    this.errorMessages = const [],
    this.errorParams,
  });
}

class PaginatedSyncCommandHandler implements IRequestHandler<PaginatedSyncCommand, PaginatedSyncCommandResponse> {
  final ISyncConfigurationService _configurationService;
  final ISyncDataProcessingService _dataProcessingService;
  final ISyncPaginationService _paginationService;
  late final SyncPageAccumulator _pageAccumulator;
  late final SyncResponseBuilder _responseBuilder;
  late final SyncProgressTracker _progressTracker;
  late final SyncDeviceCoordinator _deviceCoordinator;
  late final SyncDeviceOrchestrator _deviceOrchestrator;
  late final SyncIncomingHandler _incomingHandler;
  late final SyncOutgoingHandler _outgoingHandler;

  PaginatedSyncCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
    required ISyncConfigurationService configurationService,
    required ISyncValidationService validationService,
    required ISyncCommunicationService communicationService,
    required ISyncDataProcessingService dataProcessingService,
    required ISyncPaginationService paginationService,
    SyncPageAccumulator? pageAccumulator,
    SyncResponseBuilder? responseBuilder,
    SyncProgressTracker? progressTracker,
    SyncDeviceCoordinator? deviceCoordinator,
    SyncDeviceOrchestrator? deviceOrchestrator,
    SyncIncomingHandler? incomingHandler,
    SyncOutgoingHandler? outgoingHandler,
  })  : _configurationService = configurationService,
        _dataProcessingService = dataProcessingService,
        _paginationService = paginationService {
    _pageAccumulator = pageAccumulator ?? SyncPageAccumulator();
    _responseBuilder = responseBuilder ?? SyncResponseBuilder();
    _progressTracker = progressTracker ?? SyncProgressTracker();

    _deviceCoordinator = deviceCoordinator ??
        SyncDeviceCoordinator(
          configurationService: configurationService,
          communicationService: communicationService,
          syncDeviceRepository: syncDeviceRepository,
        );

    _deviceOrchestrator = deviceOrchestrator ??
        SyncDeviceOrchestrator(
          configurationService: configurationService,
          communicationService: communicationService,
          paginationService: paginationService,
          progressTracker: _progressTracker,
        );

    _incomingHandler = incomingHandler ??
        SyncIncomingHandler(
          configurationService: configurationService,
          validationService: validationService,
          paginationService: paginationService,
          progressTracker: _progressTracker,
        );

    _outgoingHandler = outgoingHandler ??
        SyncOutgoingHandler(
          syncDeviceRepository: syncDeviceRepository,
          paginationService: paginationService,
          deviceCoordinator: _deviceCoordinator,
        );
  }

  /// Progress stream from pagination service
  Stream<SyncProgress> get progressStream => _paginationService.progressStream;

  /// Enhanced progress tracking for bidirectional sync
  Stream<BidirectionalSyncProgress> get bidirectionalProgressStream => _progressTracker.bidirectionalProgressStream;

  /// Update bidirectional sync progress for an entity/device combination
  void _updateBidirectionalProgress(BidirectionalSyncProgress progress) {
    _progressTracker.updateProgress(progress);
  }

  /// Calculate overall sync progress across all entities and devices
  OverallSyncProgress _calculateOverallProgress() {
    return _progressTracker.calculateOverallProgress();
  }

  /// Reset all progress tracking
  void _resetProgressTracking() {
    _progressTracker.reset();
  }

  /// Dispose resources
  void dispose() {
    _progressTracker.dispose();
  }

  @override
  Future<PaginatedSyncCommandResponse> call(PaginatedSyncCommand request) async {
    Logger.info('Starting paginated sync operation...');

    try {
      if (request.paginatedSyncDataDto != null) {
        Logger.info('Handling incoming sync data');
        return await _handleIncomingSync(request.paginatedSyncDataDto!);
      } else {
        Logger.info('Initiating outgoing sync');
        return await _initiateOutgoingSync(request.targetDeviceId);
      }
    } catch (e, stackTrace) {
      Logger.error('CRITICAL: Paginated sync operation failed', error: e, stackTrace: stackTrace);

      final String errorKey;
      final Map<String, String>? errorParams;

      if (e is SyncValidationException) {
        errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
        errorParams = e.params;
        if (kDebugMode) {
          Logger.debug('SyncValidationException caught! Code: ${e.code}, params: $errorParams');
        }
      } else {
        errorKey = SyncTranslationKeys.criticalSyncOperationFailedError;
        errorParams = null;
      }

      return PaginatedSyncCommandResponse(
        isComplete: false,
        syncedDeviceCount: 0,
        hadMeaningfulSync: false,
        hasErrors: true,
        errorMessages: [errorKey],
        errorParams: errorParams,
      );
    }
  }

  Future<PaginatedSyncCommandResponse> _handleIncomingSync(PaginatedSyncDataDto dto) async {
    final result = await _incomingHandler.handleIncomingSync(
      dto,
      onProgress: _updateBidirectionalProgress,
      processDto: _processPaginatedSyncDto,
      createResponseDto: _createBidirectionalResponseDto,
    );

    return PaginatedSyncCommandResponse(
      paginatedSyncDataDto: result.responseDto,
      isComplete: !result.hasMorePagesToSend &&
          !result.hasErrors &&
          (result.responseDto == null || result.responseDto!.totalItems == 0),
      syncedDeviceCount: 1,
      hadMeaningfulSync: true,
      hasErrors: result.hasErrors,
      errorMessages: result.errors,
      errorParams: result.errorParams,
    );
  }

  Future<PaginatedSyncCommandResponse> _initiateOutgoingSync(String? targetDeviceId) async {
    final result = await _outgoingHandler.initiateOutgoingSync(
      targetDeviceId: targetDeviceId,
      syncWithDevice: _syncWithDevice,
      createResponseDto: _createBidirectionalResponseDto,
      resetProgressTracking: _resetProgressTracking,
    );

    return PaginatedSyncCommandResponse(
      isComplete: result.isComplete,
      syncedDeviceCount: result.syncedDeviceCount,
      hadMeaningfulSync: result.hadMeaningfulSync,
      hasErrors: result.hasErrors,
      errorMessages: result.errors,
      errorParams: result.errorParams,
    );
  }

  Future<bool> _syncWithDevice(SyncDevice syncDevice) async {
    return _deviceOrchestrator.syncWithDevice(
      syncDevice,
      onProgress: _updateBidirectionalProgress,
      processDto: _processPaginatedSyncDto,
      accumulatePages: _accumulateMultiplePages,
      calculateOverallProgress: _calculateOverallProgress,
    );
  }

  Future<int> _processPaginatedSyncDto(PaginatedSyncDataDto dto) async {
    int totalProcessed = 0;

    Logger.info('Processing DTO for ${dto.entityType} (${dto.totalItems} items)');

    // Process only the configuration that matches this DTO's entityType
    final config = _configurationService.getConfiguration(dto.entityType);
    if (config != null) {
      final syncData = config.getPaginatedSyncDataFromDto(dto);
      Logger.info('Processing ${config.name} (matches DTO entityType: ${dto.entityType})');
      if (syncData != null) {
        final itemCount = syncData.data.getTotalItemCount();
        Logger.info('${config.name} sync data: $itemCount total items');
        if (itemCount > 0) {
          final processedCount = await _dataProcessingService.processSyncDataBatchDynamic(
            syncData.data,
            config.repository,
          );
          totalProcessed += processedCount;
          Logger.info('Processed $processedCount ${config.name} items');
        } else {
          Logger.info('Skipping ${config.name} - no items to process');
        }
      } else {
        Logger.info('Skipping ${config.name} - no sync data found in DTO');
      }
    } else {
      Logger.warning('No configuration found for entity type: ${dto.entityType}');
    }

    return totalProcessed;
  }

  Future<PaginatedSyncDataDto> _createBidirectionalResponseDto(
    SyncDevice syncDevice,
    PaginatedSyncData localData,
    String entityType, {
    int? currentServerPage,
    int? totalServerPages,
    bool? hasMoreServerPages,
  }) async {
    return _responseBuilder.createBidirectionalResponseDto(
      syncDevice: syncDevice,
      localData: localData,
      entityType: entityType,
      currentServerPage: currentServerPage,
      totalServerPages: totalServerPages,
      hasMoreServerPages: hasMoreServerPages,
    );
  }

  /// Accumulates multiple pages of the same entity type into a single DTO for processing
  Future<PaginatedSyncDataDto> _accumulateMultiplePages(
    List<PaginatedSyncDataDto> responseDtos,
    String entityType,
  ) async {
    return _pageAccumulator.accumulatePages(responseDtos, entityType);
  }
}
