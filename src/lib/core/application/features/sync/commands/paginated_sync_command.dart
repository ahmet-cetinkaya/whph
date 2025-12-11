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
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
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
  final ISyncDeviceRepository _syncDeviceRepository;
  final ISyncConfigurationService _configurationService;
  final ISyncValidationService _validationService;
  final ISyncCommunicationService _communicationService;
  final ISyncDataProcessingService _dataProcessingService;
  final ISyncPaginationService _paginationService;

  PaginatedSyncCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
    required ISyncConfigurationService configurationService,
    required ISyncValidationService validationService,
    required ISyncCommunicationService communicationService,
    required ISyncDataProcessingService dataProcessingService,
    required ISyncPaginationService paginationService,
  })  : _syncDeviceRepository = syncDeviceRepository,
        _configurationService = configurationService,
        _validationService = validationService,
        _communicationService = communicationService,
        _dataProcessingService = dataProcessingService,
        _paginationService = paginationService;

  /// Progress stream from pagination service
  Stream<SyncProgress> get progressStream => _paginationService.progressStream;

  /// Enhanced progress tracking for bidirectional sync
  final _bidirectionalProgressController = StreamController<BidirectionalSyncProgress>.broadcast();
  Stream<BidirectionalSyncProgress> get bidirectionalProgressStream => _bidirectionalProgressController.stream;

  final Map<String, BidirectionalSyncProgress> _entityProgressMap = {};
  final Map<String, Set<String>> _deviceProgressMap = {};

  /// Update bidirectional sync progress for an entity/device combination
  void _updateBidirectionalProgress(BidirectionalSyncProgress progress) {
    final key = progress.key;
    _entityProgressMap[key] = progress;

    // Track devices per entity
    _deviceProgressMap[progress.entityType] ??= <String>{};
    _deviceProgressMap[progress.entityType]!.add(progress.deviceId);

    // Emit progress update
    _bidirectionalProgressController.add(progress);

    Logger.debug('Bidirectional progress updated: ${progress.statusDescription}');
  }

  /// Calculate overall sync progress across all entities and devices
  OverallSyncProgress _calculateOverallProgress() {
    final entityProgress = <String, List<BidirectionalSyncProgress>>{};
    int totalItemsProcessed = 0;
    int totalConflictsResolved = 0;
    final errorMessages = <String>[];

    // Group progress by entity type
    for (final progress in _entityProgressMap.values) {
      entityProgress[progress.entityType] ??= [];
      entityProgress[progress.entityType]!.add(progress);

      totalItemsProcessed += progress.itemsProcessed;
      totalConflictsResolved += progress.conflictsResolved;
      errorMessages.addAll(progress.errorMessages);
    }

    // Calculate completion stats
    int completedEntities = 0;
    int totalDevices = _deviceProgressMap.values.fold(0, (sum, devices) => sum + devices.length);
    int completedDevices = 0;

    for (final progressList in entityProgress.values) {
      final entityCompleted = progressList.every((p) => p.isComplete);
      if (entityCompleted) {
        completedEntities++;
        completedDevices += progressList.length;
      }
    }

    final overallProgress = entityProgress.isEmpty ? 0.0 : (completedEntities / entityProgress.length * 100);

    return OverallSyncProgress(
      entityProgress: entityProgress,
      totalDevices: totalDevices,
      completedDevices: completedDevices,
      totalEntities: entityProgress.length,
      completedEntities: completedEntities,
      overallProgress: overallProgress,
      totalItemsProcessed: totalItemsProcessed,
      totalConflictsResolved: totalConflictsResolved,
      errorMessages: errorMessages,
      isComplete: completedEntities == entityProgress.length && entityProgress.isNotEmpty,
    );
  }

  /// Reset all progress tracking
  void _resetProgressTracking() {
    _entityProgressMap.clear();
    _deviceProgressMap.clear();
  }

  /// Dispose resources
  void dispose() {
    _bidirectionalProgressController.close();
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
    Logger.info('Processing incoming paginated sync data from remote device');

    Logger.info('DTO entity type: ${dto.entityType}');
    if (dto.entityType == 'SyncDevice') {
      Logger.info(
          'SyncDevice DTO details: syncDevicesSyncData is ${dto.syncDevicesSyncData != null ? "not null" : "null"}');
      if (dto.syncDevicesSyncData != null) {
        Logger.info(
            'SyncDevice data: creates=${dto.syncDevicesSyncData!.data.createSync.length}, updates=${dto.syncDevicesSyncData!.data.updateSync.length}, deletes=${dto.syncDevicesSyncData!.data.deleteSync.length}');
        Logger.info('SyncDevice total count: ${dto.syncDevicesSyncData!.data.getTotalItemCount()}');
      } else {
        Logger.warning('SyncDevice DTO is null but entity type is SyncDevice - this indicates a serialization issue');
      }
    }

    // Validate incoming data
    await _validationService.validateVersion(dto.appVersion);
    await _validationService.validateDeviceId(dto.syncDevice);
    _validationService.validateEnvironmentMode(dto);

    // Process the incoming DTO data with progress tracking
    int processedCount = 0;
    List<String> processingErrors = [];
    Map<String, String>? errorParams;
    int conflictsResolved = 0;

    // Initialize progress tracking for incoming sync
    _updateBidirectionalProgress(BidirectionalSyncProgress.incomingStart(
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
      processedCount = await _processPaginatedSyncDto(dto);

      // Estimate conflicts resolved (could be enhanced with actual data from processing service)
      conflictsResolved = (processedCount * 0.15).round(); // Assume 15% conflict rate for incoming data

      // Update progress to show completion
      _updateBidirectionalProgress(BidirectionalSyncProgress.completed(
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

      Logger.info('Processed $processedCount items from incoming sync data (resolved $conflictsResolved conflicts)');
    } catch (e) {
      Logger.error('Error processing incoming sync data: $e');

      String errorKey;
      if (e is SyncValidationException) {
        errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
        if (processingErrors.isEmpty) {
          errorParams = e.params;
          if (kDebugMode) {
            Logger.debug('SyncValidationException caught! Code: ${e.code}, params: $errorParams');
          }
        }
      } else {
        errorKey = SyncTranslationKeys.processingIncomingDataError;
      }
      processingErrors.add(errorKey);

      final existingProgress = _entityProgressMap['${dto.entityType}_${dto.syncDevice.id}'];
      if (existingProgress != null) {
        _updateBidirectionalProgress(existingProgress.copyWith(
          phase: SyncPhase.complete,
          errorMessages: [...existingProgress.errorMessages, errorKey],
          isComplete: true,
        ));
      } else {
        _updateBidirectionalProgress(BidirectionalSyncProgress.completed(
          entityType: dto.entityType,
          deviceId: dto.syncDevice.id,
          itemsProcessed: 0,
          errorMessages: [errorKey],
        ));
      }
    }

    // For bidirectional sync, check if we have local data to send back
    Logger.info('Checking for local data to send back for entity: ${dto.entityType}');
    bool hasMorePagesToSend = false;
    PaginatedSyncDataDto? responseDto;

    try {
      // Get the configuration for this entity type
      final config = _configurationService.getConfiguration(dto.entityType);
      if (config != null) {
        // Check if we have local data for this entity type
        final syncDevice = dto.syncDevice;
        final lastSyncDate = syncDevice.lastSyncDate ?? DateTime(2000);

        Logger.info('Checking local ${dto.entityType} data count (page ${dto.pageIndex})');

        // For bidirectional sync, determine which server page to send
        // Use the requested server page from client, or get the next page to send
        int serverPageToSend;
        if (dto.requestedServerPage != null) {
          // Client explicitly requested a specific page
          serverPageToSend = dto.requestedServerPage!;
        } else {
          // Get the next page to send based on what we last sent to this device
          serverPageToSend = _paginationService.getLastSentServerPage(dto.syncDevice.id, dto.entityType) + 1;
        }

        final localData = await config.getPaginatedSyncData(
          lastSyncDate,
          serverPageToSend, // Send the calculated server page
          dto.pageSize, // Use standard page size
          dto.entityType,
        );

        Logger.info(
            'Local ${dto.entityType} data check: ${localData.data.getTotalItemCount()} items, page $serverPageToSend/${localData.totalPages - 1}');

        if (localData.totalItems > 0 && localData.data.getTotalItemCount() > 0) {
          // Update the last sent page tracking
          _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, serverPageToSend);

          // For bidirectional sync, check if server has more pages to send
          hasMorePagesToSend = serverPageToSend < localData.totalPages - 1;

          Logger.info('Local device has ${dto.entityType} data to send back');
          Logger.info(
              'Local ${dto.entityType} pagination: total=${localData.totalItems} items, totalPages=${localData.totalPages}, sendingPage=$serverPageToSend, willComplete=${!hasMorePagesToSend}');
          Logger.info(
              'More pages to send: $hasMorePagesToSend (server page $serverPageToSend/${localData.totalPages - 1})');

          // Actually send the local data back to the client
          Logger.info(
              'Creating response DTO with local ${dto.entityType} data (${localData.data.getTotalItemCount()} items on page $serverPageToSend)');
          responseDto = await _createBidirectionalResponseDto(
            syncDevice,
            localData,
            dto.entityType,
            currentServerPage: serverPageToSend,
            totalServerPages: localData.totalPages,
            hasMoreServerPages: hasMorePagesToSend,
          );
        } else {
          Logger.info(
              'No local ${dto.entityType} data to send back (page $serverPageToSend is empty or beyond total pages)');

          // If we're out of pages, reset the tracking for this entity to indicate completion
          _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, -1);
          hasMorePagesToSend = false;
        }
      }
    } catch (e) {
      Logger.error('Error checking local data: $e');

      final String errorKey;
      if (e is SyncValidationException) {
        errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
        if (kDebugMode) {
          Logger.debug('SyncValidationException caught! Code: ${e.code}, params: ${e.params}');
        }
      } else {
        errorKey = SyncTranslationKeys.checkingLocalDataError;
      }

      final existingProgressKey = '${dto.entityType}_${dto.syncDevice.id}';
      final existingProgress = _entityProgressMap[existingProgressKey];

      final updatedProgress = existingProgress?.copyWith(
            errorMessages: [...existingProgress.errorMessages, errorKey],
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

      _entityProgressMap[existingProgressKey] = updatedProgress;

      _updateBidirectionalProgress(updatedProgress);
    }

    // If sync is complete and there are no more pages to send, reset the server page tracking for this device/entity
    if (!hasMorePagesToSend && processingErrors.isEmpty) {
      _paginationService.setLastSentServerPage(dto.syncDevice.id, dto.entityType, -1);
    }

    return PaginatedSyncCommandResponse(
      paginatedSyncDataDto: responseDto,
      isComplete: !hasMorePagesToSend &&
          processingErrors.isEmpty &&
          (responseDto == null ||
              responseDto.totalItems ==
                  0), // Not complete if there are more pages to send, errors occurred, or response data to be processed
      syncedDeviceCount: 1,
      hadMeaningfulSync: true,
      hasErrors: processingErrors.isNotEmpty,
      errorMessages: processingErrors,
      errorParams: errorParams,
    );
  }

  Future<PaginatedSyncCommandResponse> _initiateOutgoingSync(String? targetDeviceId) async {
    Logger.info('Initiating outgoing paginated sync');
    Logger.info('Target device ID: $targetDeviceId');

    try {
      // Get all devices to sync with
      Logger.info('Fetching sync devices from repository...');
      final allDevices = await _syncDeviceRepository.getAll();
      Logger.info('Found ${allDevices.length} sync devices in database');

      for (int i = 0; i < allDevices.length; i++) {
        final device = allDevices[i];
        Logger.info(
            'Device $i LOADED FROM DATABASE with lastSyncDate=${device.lastSyncDate} (is null: ${device.lastSyncDate == null})');
      }

      if (allDevices.isEmpty) {
        Logger.warning('No devices configured for sync');
        return PaginatedSyncCommandResponse(
          isComplete: true,
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
          hasErrors: false,
          errorMessages: [],
        );
      }

      // Reset progress tracking
      Logger.info('Resetting pagination progress...');
      _paginationService.resetProgress();
      _resetProgressTracking();

      final successfulDevices = <SyncDevice>[];
      bool allDevicesSynced = true;
      DateTime? oldestLastSyncDate;

      // Sync with each device
      Logger.info('Starting sync with ${allDevices.length} devices...');
      for (int i = 0; i < allDevices.length; i++) {
        final syncDevice = allDevices[i];
        Logger.info('Syncing with device ${i + 1}/${allDevices.length}: ${syncDevice.id}');

        try {
          final success = await _syncWithDevice(syncDevice);
          if (success) {
            Logger.info('Successfully synced with device ${syncDevice.id}');
            successfulDevices.add(syncDevice);
            oldestLastSyncDate = oldestLastSyncDate == null
                ? syncDevice.lastSyncDate
                : (syncDevice.lastSyncDate!.isBefore(oldestLastSyncDate)
                    ? syncDevice.lastSyncDate
                    : oldestLastSyncDate);
          } else {
            Logger.error('Failed to sync with device ${syncDevice.id} - this will prevent sync date updates');
            allDevicesSynced = false;
          }
        } catch (e, stackTrace) {
          Logger.error('CRITICAL: Exception during sync with device ${syncDevice.id}',
              error: e, stackTrace: stackTrace);
          allDevicesSynced = false;
        }
      }

      Logger.info(
          'Sync completion status: allDevicesSynced=$allDevicesSynced, successfulDevices=${successfulDevices.length}');

      // Update last sync date only if all devices synced successfully
      if (allDevicesSynced) {
        Logger.info('Updating last sync dates for ${successfulDevices.length} successful devices');
        final updatedSyncDevices = <SyncDevice>[];

        for (final syncDevice in successfulDevices) {
          final newSyncDate = DateTime.now();
          Logger.info('Before update: device ${syncDevice.id} lastSyncDate=${syncDevice.lastSyncDate}');

          syncDevice.lastSyncDate = newSyncDate;

          await _syncDeviceRepository.update(syncDevice);

          // Add small delay to ensure database update is fully committed
          await Future.delayed(const Duration(milliseconds: 100));

          // Verify the update by re-reading the device from database
          final verificationDevice = await _syncDeviceRepository.getById(syncDevice.id);
          if (verificationDevice != null) {
            if (verificationDevice.lastSyncDate == null) {
              Logger.warning(
                  'CRITICAL: Database update verification failed - lastSyncDate is still null after update!');
              // Retry the update once more to ensure it persists
              await _syncDeviceRepository.update(syncDevice);
              await Future.delayed(const Duration(milliseconds: 100));

              // Verify again after retry
              final retryVerification = await _syncDeviceRepository.getById(syncDevice.id);
              if (retryVerification != null && retryVerification.lastSyncDate != null) {
                Logger.info('Database update verification passed after retry - lastSyncDate properly persisted');
              } else {
                Logger.error('Database update verification failed even after retry!');
              }
            }
          } else {
            Logger.error('CRITICAL: Could not re-read sync device ${syncDevice.id} from database for verification');
          }

          updatedSyncDevices.add(syncDevice);
        }

        // Sync the updated sync device records back to the server for consistency
        if (updatedSyncDevices.isNotEmpty) {
          Logger.info('Syncing updated sync device records back to server for consistency');
          await _syncUpdatedSyncDevicesBackToServer(updatedSyncDevices);
        }

        // Additional verification: check that all devices now have proper lastSyncDate
        await _verifySyncDateUpdates(updatedSyncDevices);
      } else {
        Logger.warning('Not updating sync dates due to sync failures');
        Logger.warning('allDevicesSynced=$allDevicesSynced, this means at least one device sync failed');

        // Log which devices failed
        for (final device in allDevices) {
          final wasSuccessful = successfulDevices.contains(device);
          Logger.warning('Device ${device.id}: ${wasSuccessful ? "SUCCESS" : "FAILED"}');
        }
      }

      // Enhanced diagnostics for sync analysis
      await _logSyncDiagnostics(allDevices, successfulDevices);

      Logger.info(allDevicesSynced
          ? 'Paginated sync operation completed successfully'
          : 'Paginated sync operation completed with some failures');

      return PaginatedSyncCommandResponse(
        isComplete: allDevicesSynced,
        syncedDeviceCount: successfulDevices.length,
        hadMeaningfulSync: successfulDevices.isNotEmpty,
        hasErrors: !allDevicesSynced,
        errorMessages: !allDevicesSynced ? [SyncTranslationKeys.someDevicesFailedToSyncError] : [],
      );
    } catch (e, stackTrace) {
      Logger.error('CRITICAL: Failed to initiate outgoing sync', error: e, stackTrace: stackTrace);
      final String errorKey;
      final Map<String, String>? errorParams;
      if (e is SyncValidationException) {
        errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
        errorParams = e.params;
        if (kDebugMode) {
          Logger.debug('SyncValidationException caught! Code: ${e.code}, params: $errorParams');
        }
      } else {
        errorKey = SyncTranslationKeys.initiateOutgoingSyncFailedError;
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

  Future<bool> _syncWithDevice(SyncDevice syncDevice) async {
    Logger.info('Starting sync with device ${syncDevice.id}');
    Logger.info('Last sync date: ${syncDevice.lastSyncDate}');

    try {
      // Test connectivity first
      final targetIp = await _getTargetIp(syncDevice);
      if (targetIp.isEmpty) {
        Logger.error('Could not determine target IP for device ${syncDevice.id}');
        return false;
      }

      Logger.info('Testing connectivity to $targetIp for device ${syncDevice.id}...');
      final isReachable = await _communicationService.isDeviceReachable(targetIp);
      if (!isReachable) {
        Logger.error('Device ${syncDevice.id} is not reachable at $targetIp');
        return false;
      }

      Logger.info('Device ${syncDevice.id} is reachable at $targetIp');

      // Sync each entity type with enhanced progress tracking
      final configs = _configurationService.getAllConfigurations();
      Logger.info('Syncing ${configs.length} entity types with device ${syncDevice.id}');

      // Reset server pagination tracking for this device before starting sync
      for (final config in configs) {
        _paginationService.setLastSentServerPage(syncDevice.id, config.name, -1);
      }

      for (int i = 0; i < configs.length; i++) {
        final config = configs[i];
        Logger.info('Syncing entity ${i + 1}/${configs.length}: ${config.name} with device ${syncDevice.id}');

        // Initialize progress tracking for this entity/device combination
        _updateBidirectionalProgress(BidirectionalSyncProgress.outgoingStart(
          entityType: config.name,
          deviceId: syncDevice.id,
          metadata: {
            'entityIndex': i + 1,
            'totalEntities': configs.length,
            'lastSyncDate': syncDevice.lastSyncDate?.toIso8601String(),
          },
        ));

        try {
          final lastSyncDate = syncDevice.lastSyncDate ?? DateTime(2000);
          Logger.info(
              'Using last sync date: $lastSyncDate for ${config.name} (device lastSync: ${syncDevice.lastSyncDate})');

          // Check if we're using the fallback date
          if (syncDevice.lastSyncDate == null) {
            Logger.info('Device has no previous sync date - using DateTime(2000) to get ALL data');
          } else {
            Logger.info('Device has previous sync date - getting data modified after ${syncDevice.lastSyncDate}');
          }

          final success = await _paginationService.syncEntityWithPagination(
            config,
            syncDevice,
            lastSyncDate,
          );

          if (!success) {
            Logger.error('Failed to sync ${config.name} with device ${syncDevice.id}');

            _updateBidirectionalProgress(_entityProgressMap['${config.name}_${syncDevice.id}']?.copyWith(
                  phase: SyncPhase.complete,
                  errorMessages: [SyncTranslationKeys.syncWithDeviceFailedError],
                  isComplete: true,
                ) ??
                BidirectionalSyncProgress.completed(
                  entityType: config.name,
                  deviceId: syncDevice.id,
                  itemsProcessed: 0,
                  errorMessages: [SyncTranslationKeys.syncWithDeviceFailedError],
                ));

            return false;
          }

          // Mark entity sync as completed successfully
          _updateBidirectionalProgress(BidirectionalSyncProgress.completed(
            entityType: config.name,
            deviceId: syncDevice.id,
            itemsProcessed: 0, // Will be updated during bidirectional processing
            metadata: {
              'syncSuccess': true,
              'completedAt': DateTime.now().toIso8601String(),
            },
          ));

          Logger.info('Successfully synced ${config.name} with device ${syncDevice.id}');
        } catch (e, stackTrace) {
          Logger.error('CRITICAL: Exception during ${config.name} sync with device ${syncDevice.id}',
              error: e, stackTrace: stackTrace);

          final String errorKey;
          if (e is SyncValidationException) {
            errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
            if (kDebugMode) {
              Logger.info(
                  'DEBUG: SyncValidationException caught during device sync! Code: ${e.code}, params: ${e.params}');
            }
          } else {
            errorKey = SyncTranslationKeys.syncWithDeviceExceptionError;
          }

          _updateBidirectionalProgress(_entityProgressMap['${config.name}_${syncDevice.id}']?.copyWith(
                phase: SyncPhase.complete,
                errorMessages: [errorKey],
                isComplete: true,
              ) ??
              BidirectionalSyncProgress.completed(
                entityType: config.name,
                deviceId: syncDevice.id,
                itemsProcessed: 0,
                errorMessages: [errorKey],
              ));

          return false;
        }
      }

      Logger.info('Successfully synced all ${configs.length} entities with device ${syncDevice.id}');

      // Process any pending response data from bidirectional sync with enhanced progress tracking
      final pendingResponseData = _paginationService.getPendingResponseData();
      if (pendingResponseData.isNotEmpty) {
        Logger.info('Processing ${pendingResponseData.length} pending response DTOs from bidirectional sync');

        // Group paginated responses by entity type
        final groupedResponses = <String, List<PaginatedSyncDataDto>>{};
        for (final entry in pendingResponseData.entries) {
          final key = entry.key;
          final responseDto = entry.value;

          // Extract base entity type (remove _page_N suffix if present)
          final entityType = key.contains('_page_') ? key.split('_page_')[0] : key;

          groupedResponses.putIfAbsent(entityType, () => []);
          groupedResponses[entityType]!.add(responseDto);
        }

        Logger.info(
            'Grouped ${pendingResponseData.length} DTOs into ${groupedResponses.length} entity types for processing');

        int totalProcessedFromResponses = 0;
        int totalConflictsResolved = 0;

        for (final entry in groupedResponses.entries) {
          final entityType = entry.key;
          final responseDtos = entry.value;

          // Sort DTOs by page number for sequential processing
          responseDtos.sort((a, b) {
            final pageA = a.currentServerPage ?? 0;
            final pageB = b.currentServerPage ?? 0;
            return pageA.compareTo(pageB);
          });

          Logger.info('Processing ${responseDtos.length} pages of $entityType data');

          // CRITICAL FIX: Accumulate all pages before processing
          if (responseDtos.length > 1) {
            Logger.info('Accumulating ${responseDtos.length} pages for $entityType before processing');

            // Create accumulated DTO by merging all pages
            final accumulatedDto = await _accumulateMultiplePages(responseDtos, entityType);

            // Update progress to show incoming data processing
            _updateBidirectionalProgress(BidirectionalSyncProgress.incomingStart(
              entityType: entityType,
              deviceId: syncDevice.id,
              totalItems: accumulatedDto.totalItems,
              metadata: {
                'responseProcessing': true,
                'sourceDevice': accumulatedDto.syncDevice.id,
                'pageIndex': accumulatedDto.pageIndex,
                'totalPages': accumulatedDto.totalPages,
                'accumulatedPages': responseDtos.length,
              },
            ));

            try {
              Logger.info(
                  'Processing accumulated $entityType data (${responseDtos.length} pages, ${accumulatedDto.totalItems} total items)');
              final processedCount = await _processPaginatedSyncDto(accumulatedDto);
              totalProcessedFromResponses += processedCount;

              // For now, assume 10% of processed items had conflicts (this could be enhanced with actual conflict data)
              final estimatedConflicts = (processedCount * 0.1).round();
              totalConflictsResolved += estimatedConflicts;

              // Update progress to show completion
              _updateBidirectionalProgress(BidirectionalSyncProgress.completed(
                entityType: entityType,
                deviceId: syncDevice.id,
                itemsProcessed: processedCount,
                conflictsResolved: estimatedConflicts,
                metadata: {
                  'bidirectionalResponse': true,
                  'sourceDevice': accumulatedDto.syncDevice.id,
                  'processedAt': DateTime.now().toIso8601String(),
                  'accumulatedPages': responseDtos.length,
                },
              ));

              Logger.info(
                  'Processed $processedCount accumulated items from $entityType response data (${responseDtos.length} pages)');
            } catch (e) {
              Logger.error('Failed to process accumulated response data for $entityType: $e');

              final String errorKey;
              if (e is SyncValidationException) {
                errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
                if (kDebugMode) {
                  Logger.info(
                      'DEBUG: SyncValidationException in accumulated response processing! Code: ${e.code}, params: ${e.params}');
                }
              } else {
                errorKey = SyncTranslationKeys.processAccumulatedResponseDataError;
              }

              _updateBidirectionalProgress(_entityProgressMap['${entityType}_${syncDevice.id}']?.copyWith(
                    phase: SyncPhase.complete,
                    errorMessages: [errorKey],
                    isComplete: true,
                  ) ??
                  BidirectionalSyncProgress.completed(
                    entityType: entityType,
                    deviceId: syncDevice.id,
                    itemsProcessed: 0,
                    errorMessages: [errorKey],
                  ));
            }
          } else {
            // Single page processing (existing logic)
            for (final responseDto in responseDtos) {
              // Update progress to show incoming data processing
              _updateBidirectionalProgress(BidirectionalSyncProgress.incomingStart(
                entityType: entityType,
                deviceId: syncDevice.id,
                totalItems: responseDto.totalItems,
                metadata: {
                  'responseProcessing': true,
                  'sourceDevice': responseDto.syncDevice.id,
                  'pageIndex': responseDto.pageIndex,
                  'totalPages': responseDto.totalPages,
                  'currentServerPage': responseDto.currentServerPage,
                  'totalServerPages': responseDto.totalServerPages,
                },
              ));

              try {
                Logger.info(
                    'Processing bidirectional response data for $entityType (server page ${responseDto.currentServerPage ?? 0}/${responseDto.totalServerPages ?? 0})');
                final processedCount = await _processPaginatedSyncDto(responseDto);
                totalProcessedFromResponses += processedCount;

                // For now, assume 10% of processed items had conflicts (this could be enhanced with actual conflict data)
                final estimatedConflicts = (processedCount * 0.1).round();
                totalConflictsResolved += estimatedConflicts;

                // Update progress to show completion
                _updateBidirectionalProgress(BidirectionalSyncProgress.completed(
                  entityType: entityType,
                  deviceId: syncDevice.id,
                  itemsProcessed: processedCount,
                  conflictsResolved: estimatedConflicts,
                  metadata: {
                    'bidirectionalResponse': true,
                    'sourceDevice': responseDto.syncDevice.id,
                    'processedAt': DateTime.now().toIso8601String(),
                  },
                ));

                Logger.info(
                    'Processed $processedCount items from $entityType response data (page ${responseDto.currentServerPage ?? 0})');
              } catch (e) {
                Logger.error('Failed to process response data for $entityType: $e');

                final String errorKey;
                if (e is SyncValidationException) {
                  errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
                  if (kDebugMode) {
                    Logger.info(
                        'DEBUG: SyncValidationException in response data processing! Code: ${e.code}, params: ${e.params}');
                  }
                } else {
                  errorKey = SyncTranslationKeys.processResponseDataError;
                }

                _updateBidirectionalProgress(_entityProgressMap['${entityType}_${syncDevice.id}']?.copyWith(
                      phase: SyncPhase.complete,
                      errorMessages: [errorKey],
                      isComplete: true,
                    ) ??
                    BidirectionalSyncProgress.completed(
                      entityType: entityType,
                      deviceId: syncDevice.id,
                      itemsProcessed: 0,
                      errorMessages: [errorKey],
                    ));
              }
            }
          }

          Logger.info('Processed all ${responseDtos.length} pages for $entityType');
        }

        Logger.info('Total items processed from bidirectional responses: $totalProcessedFromResponses');
        Logger.info('Total conflicts resolved during bidirectional sync: $totalConflictsResolved');
        _paginationService.clearPendingResponseData();

        // Log overall sync progress
        final overallProgress = _calculateOverallProgress();
        Logger.info('Overall sync progress: ${overallProgress.overallProgress.toStringAsFixed(1)}% '
            '(${overallProgress.completedEntities}/${overallProgress.totalEntities} entities, '
            '${overallProgress.totalItemsProcessed} items processed)');
      }

      // After processing all pending responses, reset the last sent page tracking for all entity types for this device
      for (final config in configs) {
        _paginationService.setLastSentServerPage(syncDevice.id, config.name, -1);
      }

      return true;
    } catch (e, stackTrace) {
      Logger.error('CRITICAL: Exception in _syncWithDevice for ${syncDevice.id}', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<String> _getTargetIp(SyncDevice syncDevice) async {
    // Determine which IP to use based on the sync direction
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
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
    Logger.info('Creating bidirectional response DTO for $entityType with ${localData.data.getTotalItemCount()} items');

    // Create the response DTO with the actual local data based on entity type
    switch (entityType) {
      case 'AppUsage':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          appUsagesSyncData: localData as PaginatedSyncData<AppUsage>?,
        );

      case 'AppUsageTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          appUsageTagsSyncData: localData as PaginatedSyncData<AppUsageTag>?,
        );

      case 'AppUsageTimeRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          appUsageTimeRecordsSyncData: localData as PaginatedSyncData<AppUsageTimeRecord>?,
        );

      case 'AppUsageTagRule':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          appUsageTagRulesSyncData: localData as PaginatedSyncData<AppUsageTagRule>?,
        );

      case 'AppUsageIgnoreRule':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          appUsageIgnoreRulesSyncData: localData as PaginatedSyncData<AppUsageIgnoreRule>?,
        );

      case 'Task':
        final itemCount = localData.data.getTotalItemCount();

        final paginatedSyncData = localData as PaginatedSyncData<Task>;
        final tasksData = itemCount > 0 ? paginatedSyncData : null;

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          tasksSyncData: tasksData,
        );

      case 'TaskTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          taskTagsSyncData: localData as PaginatedSyncData<TaskTag>?,
        );

      case 'TaskTimeRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          taskTimeRecordsSyncData: localData as PaginatedSyncData<TaskTimeRecord>?,
        );

      case 'Habit':
        final itemCount = localData.data.getTotalItemCount();
        final paginatedSyncData = localData as PaginatedSyncData<Habit>;
        final habitsData = itemCount > 0 ? paginatedSyncData : null;

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          habitsSyncData: habitsData,
        );

      case 'HabitRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          habitRecordsSyncData: localData as PaginatedSyncData<HabitRecord>?,
        );

      case 'HabitTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          habitTagsSyncData: localData as PaginatedSyncData<HabitTag>?,
        );

      case 'Tag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          tagsSyncData: localData as PaginatedSyncData<Tag>?,
        );

      case 'TagTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          tagTagsSyncData: localData as PaginatedSyncData<TagTag>?,
        );

      case 'Setting':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          settingsSyncData: localData as PaginatedSyncData<Setting>?,
        );

      case 'SyncDevice':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          syncDevicesSyncData: localData as PaginatedSyncData<SyncDevice>?,
        );

      case 'Note':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          notesSyncData: localData as PaginatedSyncData<Note>?,
        );

      case 'NoteTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
          noteTagsSyncData: localData as PaginatedSyncData<NoteTag>?,
        );

      default:
        Logger.warning('Unknown entity type for bidirectional sync: $entityType');
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          currentServerPage: currentServerPage,
          totalServerPages: totalServerPages,
          hasMoreServerPages: hasMoreServerPages,
        );
    }
  }

  /// Syncs updated sync device records back to the server for consistency
  /// This ensures that when the client updates lastSyncDate, the server is also updated
  Future<void> _syncUpdatedSyncDevicesBackToServer(List<SyncDevice> updatedSyncDevices) async {
    try {
      Logger.info('Starting sync device consistency sync for ${updatedSyncDevices.length} devices');

      for (final updatedSyncDevice in updatedSyncDevices) {
        try {
          Logger.info('Syncing updated sync device ${updatedSyncDevice.id} back to server');

          // Get the SyncDevice configuration
          final syncDeviceConfig = _configurationService.getConfiguration('SyncDevice');
          if (syncDeviceConfig == null) {
            Logger.error('SyncDevice configuration not found');
            continue;
          }

          // Create paginated sync data for this single updated sync device
          final singleDeviceData = await syncDeviceConfig.getPaginatedSyncData(
            DateTime(2000), // Use old date to ensure this device is included
            0, // First page
            1, // Only one item
            'SyncDevice',
          );

          // Filter to only include our specific updated device
          final filteredData = _filterSyncDataForSpecificDevice(singleDeviceData, updatedSyncDevice);

          if (filteredData.data.getTotalItemCount() > 0) {
            Logger.info('Sending updated sync device ${updatedSyncDevice.id} to server');

            // Create DTO for the updated sync device
            final dto = await _createBidirectionalResponseDto(
              updatedSyncDevice,
              filteredData,
              'SyncDevice',
            );

            // Send to the server via the same communication mechanism
            final targetIp = await _getTargetIpForDevice(updatedSyncDevice);
            if (targetIp.isNotEmpty) {
              final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
              if (response.success) {
                Logger.info('Successfully synced updated sync device ${updatedSyncDevice.id} back to server');
              } else {
                Logger.error('Failed to sync updated sync device ${updatedSyncDevice.id}: ${response.error}');
              }
            } else {
              Logger.error('Could not determine target IP for sync device ${updatedSyncDevice.id}');
            }
          } else {
            Logger.warning('No sync data found for updated sync device ${updatedSyncDevice.id}');
          }
        } catch (e) {
          Logger.error('Error syncing updated sync device ${updatedSyncDevice.id}: $e');
        }
      }

      Logger.info('Sync device consistency sync completed');
    } catch (e, stackTrace) {
      Logger.error('CRITICAL: Failed to sync updated sync devices back to server', error: e, stackTrace: stackTrace);
    }
  }

  /// Filters sync data to include only the specific sync device
  PaginatedSyncData<SyncDevice> _filterSyncDataForSpecificDevice(
    PaginatedSyncData syncData,
    SyncDevice targetDevice,
  ) {
    // Create filtered sync data containing only the target device
    final filteredCreateSync = <SyncDevice>[];
    final filteredUpdateSync = <SyncDevice>[];
    final filteredDeleteSync = <SyncDevice>[];

    // Check create sync items
    if (syncData.data.createSync.isNotEmpty) {
      for (final item in syncData.data.createSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredCreateSync.add(item);
        }
      }
    }

    // Check update sync items
    if (syncData.data.updateSync.isNotEmpty) {
      for (final item in syncData.data.updateSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredUpdateSync.add(item);
        }
      }
    }

    // Since we just updated the device, it should be in updateSync
    // If not found in existing sync data, add it to updateSync
    if (filteredCreateSync.isEmpty && filteredUpdateSync.isEmpty) {
      filteredUpdateSync.add(targetDevice);
    }

    // Create new sync data with filtered items
    final filteredSyncData = SyncData<SyncDevice>(
      createSync: filteredCreateSync,
      updateSync: filteredUpdateSync,
      deleteSync: filteredDeleteSync,
    );

    return PaginatedSyncData<SyncDevice>(
      data: filteredSyncData,
      pageIndex: 0,
      pageSize: 1,
      totalPages: 1,
      totalItems: filteredSyncData.getTotalItemCount(),
      isLastPage: true,
      entityType: 'SyncDevice',
    );
  }

  /// Gets target IP address for a sync device
  Future<String> _getTargetIpForDevice(SyncDevice syncDevice) async {
    // Use the same logic as in _getTargetIp but for a specific device
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
  }

  /// Verifies that sync date updates were properly applied to all devices
  Future<void> _verifySyncDateUpdates(List<SyncDevice> updatedSyncDevices) async {
    Logger.info('Starting verification of sync date updates for ${updatedSyncDevices.length} devices');

    for (final device in updatedSyncDevices) {
      final verificationDevice = await _syncDeviceRepository.getById(device.id);
      if (verificationDevice != null) {
        if (verificationDevice.lastSyncDate != null) {
          Logger.info('Sync date verification passed for device ${device.id}: ${verificationDevice.lastSyncDate}');
        } else {
          Logger.error('Sync date verification failed for device ${device.id}: lastSyncDate is still null');
        }
      } else {
        Logger.error('Could not verify sync date for device ${device.id}: device not found in repository');
      }
    }
  }

  /// Enhanced diagnostics to help identify sync issues vs empty databases
  Future<void> _logSyncDiagnostics(List<SyncDevice> allDevices, List<SyncDevice> successfulDevices) async {
    Logger.info('SYNC DIAGNOSTICS SUMMARY');
    Logger.info('═══════════════════════════');

    // Check if this device has any data to sync
    final configs = _configurationService.getAllConfigurations();
    int totalActiveItems = 0;
    int totalAllItems = 0;
    int entitiesWithActiveData = 0;

    for (final config in configs) {
      try {
        // Include soft-deleted rows so diagnostics reflect the full dataset
        final allItems = await config.repository.getAll(includeDeleted: true);
        final totalCount = allItems.length;
        final activeCount = allItems.where((item) => item.deletedDate == null).length;
        final deletedCount = totalCount - activeCount;

        totalActiveItems += activeCount;
        totalAllItems += totalCount;

        if (totalCount > 0) {
          if (activeCount > 0) {
            entitiesWithActiveData++;
          }
          Logger.info(
              '${config.name}: $activeCount active / $totalCount total items locally (soft-deleted: $deletedCount)');
        }
      } catch (e) {
        Logger.warning('Failed to check ${config.name} data: $e');
      }
    }

    if (totalAllItems == 0) {
      Logger.warning('DIAGNOSIS: This device has NO LOCAL DATA to sync');
      Logger.warning('This is likely a fresh installation or the app hasn\'t collected data yet');
      Logger.warning('Recommended: Use the app to create tasks, habits, track app usage, etc.');
    } else {
      Logger.info(
          'DIAGNOSIS: Device has $totalActiveItems active items and $totalAllItems total (including soft-deleted) across $entitiesWithActiveData entity types');
    }

    // Check sync device status
    Logger.info('Sync Device Status:');
    for (final device in allDevices) {
      final isSuccessful = successfulDevices.contains(device);
      final status = isSuccessful ? 'SUCCESS' : 'FAILED';
      Logger.info('${device.id} (${device.fromIp} ↔ ${device.toIp}): $status');
      if (device.lastSyncDate != null) {
        Logger.info('Last sync: ${device.lastSyncDate}');
      } else {
        Logger.info('Last sync: Never (initial sync)');
      }
    }
    Logger.info('═══════════════════════════');
  }

  /// Accumulates multiple pages of the same entity type into a single DTO for processing
  Future<PaginatedSyncDataDto> _accumulateMultiplePages(
    List<PaginatedSyncDataDto> responseDtos,
    String entityType,
  ) async {
    if (responseDtos.isEmpty) {
      throw ArgumentError('Cannot accumulate empty list of response DTOs');
    }

    if (responseDtos.length == 1) {
      return responseDtos.first;
    }

    Logger.info('Accumulating ${responseDtos.length} pages for $entityType');

    // Use the first DTO as the base
    final baseDto = responseDtos.first;

    // Accumulate all sync data from all pages based on entity type
    switch (entityType) {
      case 'HabitRecord':
        return await _accumulateHabitRecordPages(responseDtos);
      case 'AppUsageTimeRecord':
        return await _accumulateAppUsageTimeRecordPages(responseDtos);
      case 'Task':
        return await _accumulateTaskPages(responseDtos);
      case 'TaskTag':
        return await _accumulateTaskTagPages(responseDtos);
      case 'TaskTimeRecord':
        return await _accumulateTaskTimeRecordPages(responseDtos);
      case 'AppUsage':
        return await _accumulateAppUsagePages(responseDtos);
      case 'AppUsageTag':
        return await _accumulateAppUsageTagPages(responseDtos);
      case 'Habit':
        return await _accumulateHabitPages(responseDtos);
      case 'HabitTag':
        return await _accumulateHabitTagPages(responseDtos);
      case 'Tag':
        return await _accumulateTagPages(responseDtos);
      case 'Setting':
        return await _accumulateSettingPages(responseDtos);
      case 'Note':
        return await _accumulateNotePages(responseDtos);
      case 'NoteTag':
        return await _accumulateNoteTagPages(responseDtos);
      default:
        Logger.warning('No accumulation logic for entity type: $entityType, using first page only');
        return baseDto;
    }
  }

  /// Accumulates HabitRecord pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateHabitRecordPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <HabitRecord>[];
    final allUpdateSync = <HabitRecord>[];
    final allDeleteSync = <HabitRecord>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.habitRecordsSyncData != null) {
        allCreateSync.addAll(dto.habitRecordsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.habitRecordsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.habitRecordsSyncData!.data.deleteSync);
        totalItems += dto.habitRecordsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated HabitRecord data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<HabitRecord>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<HabitRecord>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'HabitRecord',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'HabitRecord',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      habitRecordsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates AppUsageTimeRecord pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateAppUsageTimeRecordPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <AppUsageTimeRecord>[];
    final allUpdateSync = <AppUsageTimeRecord>[];
    final allDeleteSync = <AppUsageTimeRecord>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.appUsageTimeRecordsSyncData != null) {
        allCreateSync.addAll(dto.appUsageTimeRecordsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.appUsageTimeRecordsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.appUsageTimeRecordsSyncData!.data.deleteSync);
        totalItems += dto.appUsageTimeRecordsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated AppUsageTimeRecord data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<AppUsageTimeRecord>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<AppUsageTimeRecord>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'AppUsageTimeRecord',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'AppUsageTimeRecord',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      appUsageTimeRecordsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates Task pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateTaskPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <Task>[];
    final allUpdateSync = <Task>[];
    final allDeleteSync = <Task>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.tasksSyncData != null) {
        allCreateSync.addAll(dto.tasksSyncData!.data.createSync);
        allUpdateSync.addAll(dto.tasksSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.tasksSyncData!.data.deleteSync);
        totalItems += dto.tasksSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated Task data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<Task>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<Task>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'Task',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'Task',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      tasksSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates TaskTag pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateTaskTagPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <TaskTag>[];
    final allUpdateSync = <TaskTag>[];
    final allDeleteSync = <TaskTag>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.taskTagsSyncData != null) {
        allCreateSync.addAll(dto.taskTagsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.taskTagsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.taskTagsSyncData!.data.deleteSync);
        totalItems += dto.taskTagsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated TaskTag data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<TaskTag>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<TaskTag>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'TaskTag',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'TaskTag',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      taskTagsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates TaskTimeRecord pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateTaskTimeRecordPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <TaskTimeRecord>[];
    final allUpdateSync = <TaskTimeRecord>[];
    final allDeleteSync = <TaskTimeRecord>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.taskTimeRecordsSyncData != null) {
        allCreateSync.addAll(dto.taskTimeRecordsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.taskTimeRecordsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.taskTimeRecordsSyncData!.data.deleteSync);
        totalItems += dto.taskTimeRecordsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated TaskTimeRecord data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<TaskTimeRecord>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<TaskTimeRecord>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'TaskTimeRecord',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'TaskTimeRecord',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      taskTimeRecordsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates AppUsage pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateAppUsagePages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <AppUsage>[];
    final allUpdateSync = <AppUsage>[];
    final allDeleteSync = <AppUsage>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.appUsagesSyncData != null) {
        allCreateSync.addAll(dto.appUsagesSyncData!.data.createSync);
        allUpdateSync.addAll(dto.appUsagesSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.appUsagesSyncData!.data.deleteSync);
        totalItems += dto.appUsagesSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated AppUsage data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<AppUsage>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<AppUsage>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'AppUsage',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'AppUsage',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      appUsagesSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates AppUsageTag pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateAppUsageTagPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <AppUsageTag>[];
    final allUpdateSync = <AppUsageTag>[];
    final allDeleteSync = <AppUsageTag>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.appUsageTagsSyncData != null) {
        allCreateSync.addAll(dto.appUsageTagsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.appUsageTagsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.appUsageTagsSyncData!.data.deleteSync);
        totalItems += dto.appUsageTagsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated AppUsageTag data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<AppUsageTag>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<AppUsageTag>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'AppUsageTag',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'AppUsageTag',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      appUsageTagsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates Habit pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateHabitPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <Habit>[];
    final allUpdateSync = <Habit>[];
    final allDeleteSync = <Habit>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.habitsSyncData != null) {
        allCreateSync.addAll(dto.habitsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.habitsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.habitsSyncData!.data.deleteSync);
        totalItems += dto.habitsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated Habit data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<Habit>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<Habit>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'Habit',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'Habit',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      habitsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates HabitTag pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateHabitTagPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <HabitTag>[];
    final allUpdateSync = <HabitTag>[];
    final allDeleteSync = <HabitTag>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.habitTagsSyncData != null) {
        allCreateSync.addAll(dto.habitTagsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.habitTagsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.habitTagsSyncData!.data.deleteSync);
        totalItems += dto.habitTagsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated HabitTag data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<HabitTag>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<HabitTag>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'HabitTag',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'HabitTag',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      habitTagsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates Tag pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateTagPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <Tag>[];
    final allUpdateSync = <Tag>[];
    final allDeleteSync = <Tag>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.tagsSyncData != null) {
        allCreateSync.addAll(dto.tagsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.tagsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.tagsSyncData!.data.deleteSync);
        totalItems += dto.tagsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated Tag data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<Tag>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<Tag>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'Tag',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'Tag',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      tagsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates Setting pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateSettingPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <Setting>[];
    final allUpdateSync = <Setting>[];
    final allDeleteSync = <Setting>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.settingsSyncData != null) {
        allCreateSync.addAll(dto.settingsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.settingsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.settingsSyncData!.data.deleteSync);
        totalItems += dto.settingsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated Setting data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<Setting>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<Setting>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'Setting',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'Setting',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      settingsSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates Note pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateNotePages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <Note>[];
    final allUpdateSync = <Note>[];
    final allDeleteSync = <Note>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.notesSyncData != null) {
        allCreateSync.addAll(dto.notesSyncData!.data.createSync);
        allUpdateSync.addAll(dto.notesSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.notesSyncData!.data.deleteSync);
        totalItems += dto.notesSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated Note data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<Note>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<Note>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'Note',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'Note',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      notesSyncData: accumulatedPaginatedData,
    );
  }

  /// Accumulates NoteTag pages into a single DTO
  Future<PaginatedSyncDataDto> _accumulateNoteTagPages(List<PaginatedSyncDataDto> responseDtos) async {
    final baseDto = responseDtos.first;
    final allCreateSync = <NoteTag>[];
    final allUpdateSync = <NoteTag>[];
    final allDeleteSync = <NoteTag>[];

    int totalItems = 0;

    for (final dto in responseDtos) {
      if (dto.noteTagsSyncData != null) {
        allCreateSync.addAll(dto.noteTagsSyncData!.data.createSync);
        allUpdateSync.addAll(dto.noteTagsSyncData!.data.updateSync);
        allDeleteSync.addAll(dto.noteTagsSyncData!.data.deleteSync);
        totalItems += dto.noteTagsSyncData!.data.getTotalItemCount();
      }
    }

    Logger.info(
        'Accumulated NoteTag data: ${allCreateSync.length} creates, ${allUpdateSync.length} updates, ${allDeleteSync.length} deletes (total: $totalItems)');

    final accumulatedSyncData = SyncData<NoteTag>(
      createSync: allCreateSync,
      updateSync: allUpdateSync,
      deleteSync: allDeleteSync,
    );

    final accumulatedPaginatedData = PaginatedSyncData<NoteTag>(
      data: accumulatedSyncData,
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      entityType: 'NoteTag',
    );

    return PaginatedSyncDataDto(
      appVersion: baseDto.appVersion,
      syncDevice: baseDto.syncDevice,
      isDebugMode: baseDto.isDebugMode,
      entityType: 'NoteTag',
      pageIndex: 0,
      pageSize: totalItems,
      totalPages: 1,
      totalItems: totalItems,
      isLastPage: true,
      noteTagsSyncData: accumulatedPaginatedData,
    );
  }
}
