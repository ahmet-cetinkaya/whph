import 'package:flutter/foundation.dart';
import 'package:application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:application/features/sync/commands/paginated_sync_command/services/sync_progress_tracker.dart';
import 'package:application/features/sync/constants/sync_translation_keys.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/shared/utils/logger.dart';

/// Callback types for progress updates
typedef ProgressCallback = void Function(BidirectionalSyncProgress progress);
typedef DtoProcessor = Future<int> Function(PaginatedSyncDataDto dto);
typedef PageAccumulator = Future<PaginatedSyncDataDto> Function(List<PaginatedSyncDataDto> dtos, String entityType);
typedef OverallProgressCalculator = OverallSyncProgress Function();

/// Orchestrates sync operations with individual devices.
class SyncDeviceOrchestrator {
  final ISyncConfigurationService _configurationService;
  final ISyncCommunicationService _communicationService;
  final ISyncPaginationService _paginationService;
  final SyncProgressTracker _progressTracker;

  SyncDeviceOrchestrator({
    required ISyncConfigurationService configurationService,
    required ISyncCommunicationService communicationService,
    required ISyncPaginationService paginationService,
    required SyncProgressTracker progressTracker,
  })  : _configurationService = configurationService,
        _communicationService = communicationService,
        _paginationService = paginationService,
        _progressTracker = progressTracker;

  /// Syncs all entity types with a specific device.
  Future<bool> syncWithDevice(
    SyncDevice syncDevice, {
    required ProgressCallback onProgress,
    required DtoProcessor processDto,
    required PageAccumulator accumulatePages,
    required OverallProgressCalculator calculateOverallProgress,
  }) async {
    DomainLogger.info('Starting sync with device ${syncDevice.id}');
    DomainLogger.info('Last sync date: ${syncDevice.lastSyncDate}');

    try {
      // Test connectivity
      final targetIp = _getTargetIp(syncDevice);
      if (targetIp.isEmpty) {
        DomainLogger.error('Could not determine target IP for device ${syncDevice.id}');
        return false;
      }

      DomainLogger.info('Testing connectivity to $targetIp for device ${syncDevice.id}...');
      final isReachable = await _communicationService.isDeviceReachable(targetIp);
      if (!isReachable) {
        DomainLogger.error('Device ${syncDevice.id} is not reachable at $targetIp');
        return false;
      }

      DomainLogger.info('Device ${syncDevice.id} is reachable at $targetIp');

      final configs = _configurationService.getAllConfigurations();
      DomainLogger.info('Syncing ${configs.length} entity types with device ${syncDevice.id}');

      // Reset server pagination tracking
      for (final config in configs) {
        _paginationService.setLastSentServerPage(syncDevice.id, config.name, -1);
      }

      // Sync each entity type
      for (int i = 0; i < configs.length; i++) {
        final config = configs[i];
        DomainLogger.info('Syncing entity ${i + 1}/${configs.length}: ${config.name} with device ${syncDevice.id}');

        onProgress(BidirectionalSyncProgress.outgoingStart(
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
          DomainLogger.info('Using last sync date: $lastSyncDate for ${config.name}');

          final success = await _paginationService.syncEntityWithPagination(config, syncDevice, lastSyncDate);

          if (!success) {
            DomainLogger.error('Failed to sync ${config.name} with device ${syncDevice.id}');
            _emitErrorProgress(onProgress, config.name, syncDevice.id, SyncTranslationKeys.syncWithDeviceFailedError);
            return false;
          }

          onProgress(BidirectionalSyncProgress.completed(
            entityType: config.name,
            deviceId: syncDevice.id,
            itemsProcessed: 0,
            metadata: {'syncSuccess': true, 'completedAt': DateTime.now().toIso8601String()},
          ));

          DomainLogger.info('Successfully synced ${config.name} with device ${syncDevice.id}');
        } catch (e, stackTrace) {
          DomainLogger.error('CRITICAL: Exception during ${config.name} sync', error: e, stackTrace: stackTrace);
          final errorKey = _getErrorKey(e);
          _emitErrorProgress(onProgress, config.name, syncDevice.id, errorKey);
          return false;
        }
      }

      DomainLogger.info('Successfully synced all ${configs.length} entities with device ${syncDevice.id}');

      // Process pending responses
      await _processPendingResponses(
        syncDevice: syncDevice,
        onProgress: onProgress,
        processDto: processDto,
        accumulatePages: accumulatePages,
        calculateOverallProgress: calculateOverallProgress,
      );

      // Reset pagination tracking
      for (final config in configs) {
        _paginationService.setLastSentServerPage(syncDevice.id, config.name, -1);
      }

      return true;
    } catch (e, stackTrace) {
      DomainLogger.error('CRITICAL: Exception in syncWithDevice for ${syncDevice.id}',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _processPendingResponses({
    required SyncDevice syncDevice,
    required ProgressCallback onProgress,
    required DtoProcessor processDto,
    required PageAccumulator accumulatePages,
    required OverallProgressCalculator calculateOverallProgress,
  }) async {
    final pendingResponseData = _paginationService.getPendingResponseData();
    if (pendingResponseData.isEmpty) return;

    DomainLogger.info('Processing ${pendingResponseData.length} pending response DTOs');

    // Group by entity type
    final groupedResponses = <String, List<PaginatedSyncDataDto>>{};
    for (final entry in pendingResponseData.entries) {
      final entityType = entry.key.contains('_page_') ? entry.key.split('_page_')[0] : entry.key;
      groupedResponses.putIfAbsent(entityType, () => []);
      groupedResponses[entityType]!.add(entry.value);
    }

    DomainLogger.info('Grouped into ${groupedResponses.length} entity types');

    int totalProcessed = 0;
    int totalConflicts = 0;

    for (final entry in groupedResponses.entries) {
      final entityType = entry.key;
      final responseDtos = entry.value..sort((a, b) => (a.currentServerPage ?? 0).compareTo(b.currentServerPage ?? 0));

      DomainLogger.info('Processing ${responseDtos.length} pages of $entityType');

      if (responseDtos.length > 1) {
        final accumulatedDto = await accumulatePages(responseDtos, entityType);
        final result = await _processEntityResponse(
          entityType: entityType,
          syncDevice: syncDevice,
          dto: accumulatedDto,
          pageCount: responseDtos.length,
          onProgress: onProgress,
          processDto: processDto,
        );
        totalProcessed += result.processed;
        totalConflicts += result.conflicts;
      } else {
        for (final dto in responseDtos) {
          final result = await _processEntityResponse(
            entityType: entityType,
            syncDevice: syncDevice,
            dto: dto,
            pageCount: 1,
            onProgress: onProgress,
            processDto: processDto,
          );
          totalProcessed += result.processed;
          totalConflicts += result.conflicts;
        }
      }

      DomainLogger.info('Processed all ${responseDtos.length} pages for $entityType');
    }

    DomainLogger.info('Total processed: $totalProcessed, conflicts: $totalConflicts');
    _paginationService.clearPendingResponseData();

    final overallProgress = calculateOverallProgress();
    DomainLogger.info('Overall progress: ${overallProgress.overallProgress.toStringAsFixed(1)}%');
  }

  Future<({int processed, int conflicts})> _processEntityResponse({
    required String entityType,
    required SyncDevice syncDevice,
    required PaginatedSyncDataDto dto,
    required int pageCount,
    required ProgressCallback onProgress,
    required DtoProcessor processDto,
  }) async {
    onProgress(BidirectionalSyncProgress.incomingStart(
      entityType: entityType,
      deviceId: syncDevice.id,
      totalItems: dto.totalItems,
      metadata: {
        'responseProcessing': true,
        'sourceDevice': dto.syncDevice.id,
        'pageIndex': dto.pageIndex,
        'totalPages': dto.totalPages,
        'accumulatedPages': pageCount,
      },
    ));

    try {
      final processedCount = await processDto(dto);
      final estimatedConflicts = (processedCount * 0.1).round();

      onProgress(BidirectionalSyncProgress.completed(
        entityType: entityType,
        deviceId: syncDevice.id,
        itemsProcessed: processedCount,
        conflictsResolved: estimatedConflicts,
        metadata: {
          'bidirectionalResponse': true,
          'sourceDevice': dto.syncDevice.id,
          'processedAt': DateTime.now().toIso8601String(),
          'accumulatedPages': pageCount,
        },
      ));

      DomainLogger.info('Processed $processedCount items from $entityType ($pageCount pages)');
      return (processed: processedCount, conflicts: estimatedConflicts);
    } catch (e) {
      DomainLogger.error('Failed to process $entityType: $e');
      final errorKey = _getErrorKey(e);
      _emitErrorProgress(onProgress, entityType, syncDevice.id, errorKey);
      return (processed: 0, conflicts: 0);
    }
  }

  String _getTargetIp(SyncDevice syncDevice) {
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
  }

  String _getErrorKey(dynamic e) {
    if (e is SyncValidationException) {
      if (kDebugMode) {
        DomainLogger.info('DEBUG: SyncValidationException! Code: ${e.code}, params: ${e.params}');
      }
      return e.code ?? SyncTranslationKeys.syncFailedError;
    }
    return SyncTranslationKeys.syncWithDeviceExceptionError;
  }

  void _emitErrorProgress(ProgressCallback onProgress, String entityType, String deviceId, String errorKey) {
    final existing = _progressTracker.getProgress('${entityType}_$deviceId');
    onProgress(existing?.copyWith(
          phase: SyncPhase.complete,
          errorMessages: [errorKey],
          isComplete: true,
        ) ??
        BidirectionalSyncProgress.completed(
          entityType: entityType,
          deviceId: deviceId,
          itemsProcessed: 0,
          errorMessages: [errorKey],
        ));
  }
}
