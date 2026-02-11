import 'dart:async';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service/helpers/server_pagination_handler.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service/helpers/sync_dto_builder.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service/helpers/sync_progress_tracker.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Implementation of sync pagination service
/// Orchestrates sync operations by delegating to specialized helpers
class SyncPaginationService implements ISyncPaginationService {
  final ISyncCommunicationService _communicationService;
  final ISyncConfigurationService _configurationService;

  late final SyncProgressTracker _progressTracker;
  late final ServerPaginationHandler _serverPaginationHandler;
  late final SyncDtoBuilder _dtoBuilder;

  // Active sync state
  final Set<String> _activeEntityTypes = <String>{};
  bool _isSyncCancelled = false;

  SyncPaginationService({
    required ISyncCommunicationService communicationService,
    required ISyncConfigurationService configurationService,
  })  : _communicationService = communicationService,
        _configurationService = configurationService {
    _progressTracker = SyncProgressTracker(_configurationService);
    _serverPaginationHandler = ServerPaginationHandler(_communicationService);
    _dtoBuilder = SyncDtoBuilder();
  }

  @override
  Stream<SyncProgress> get progressStream => _progressTracker.progressStream;

  @override
  Future<bool> syncEntityWithPagination(
    PaginatedSyncConfig config,
    SyncDevice syncDevice,
    DateTime lastSyncDate, {
    String? targetDeviceId,
  }) async {
    if (_isSyncCancelled) {
      Logger.warning('Sync operation was cancelled');
      return false;
    }

    final String targetIp = _getTargetIpFromSyncDevice(syncDevice);
    Logger.debug('Using target IP: $targetIp for ${config.name} sync with device ${syncDevice.id}');

    if (targetIp.isEmpty) {
      Logger.error('Could not determine target IP address from sync device ${syncDevice.id}');
      return false;
    }

    _activeEntityTypes.add(config.name);

    try {
      final DateTime effectiveLastSyncDate = lastSyncDate;
      int pageIndex = 0;
      bool hasMorePages = true;

      Logger.info('Starting paginated sync for ${config.name}');
      Logger.info('Using sync date filter: $effectiveLastSyncDate');

      while (hasMorePages && !_isSyncCancelled) {
        try {
          _progressTracker.updateProgress(
            currentEntity: config.name,
            currentPage: pageIndex,
            totalPages: -1,
            progressPercentage: 0.0,
            entitiesCompleted: 0,
            totalEntities: _configurationService.getAllConfigurations().length,
            operation: 'fetching',
          );

          Logger.info(
              'Fetching ${config.name} data (page $pageIndex, pageSize: ${SyncPaginationConfig.defaultNetworkPageSize}, lastSync: $effectiveLastSyncDate)');

          // Get paginated data for this entity
          final paginatedData = await config.getPaginatedSyncData(
            effectiveLastSyncDate,
            pageIndex,
            SyncPaginationConfig.defaultNetworkPageSize,
            config.name,
          );

          Logger.info(
              '${config.name} page $pageIndex: ${paginatedData.data.getTotalItemCount()} items, totalPages: ${paginatedData.totalPages}, isLastPage: ${paginatedData.isLastPage}');

          // Update progress
          final entityProgress =
              paginatedData.totalPages > 0 ? ((pageIndex + 1) / paginatedData.totalPages * 100) : 100.0;
          _progressTracker.updateProgress(
            currentEntity: config.name,
            currentPage: pageIndex,
            totalPages: paginatedData.totalPages,
            progressPercentage: entityProgress,
            entitiesCompleted: 0,
            totalEntities: _configurationService.getAllConfigurations().length,
            operation: 'transmitting',
          );

          // Skip empty pages (optimization)
          final itemCount = paginatedData.data.getTotalItemCount();
          if (itemCount == 0 && pageIndex > 0) {
            Logger.info('Skipping empty ${config.name} page $pageIndex - no data to send');
            break;
          }

          // Build DTO using helper
          final progress = _progressTracker.getCurrentProgress(config.name);
          final dto = _dtoBuilder.buildDto(
            syncDevice: syncDevice,
            paginatedData: paginatedData,
            entityType: config.name,
            progress: progress,
          );

          // Send page to remote device
          final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
          if (!response.success) {
            Logger.error('Failed to send ${config.name} page $pageIndex: ${response.error}');
            return false;
          }

          // Handle bidirectional sync response
          if (!response.isComplete && response.responseData != null) {
            Logger.info('Server has data to send back for ${config.name} - storing for later processing');
            _serverPaginationHandler.storePendingResponse(config.name, response.responseData!);

            // Request additional server pages if available
            final responseData = response.responseData!;
            if (responseData.hasMoreServerPages == true) {
              final currentServerPage = responseData.currentServerPage ?? 0;
              final totalServerPages = responseData.totalServerPages ?? 1;

              Logger.info('Server has more pages for ${config.name} (page ${currentServerPage + 1}/$totalServerPages)');

              await _serverPaginationHandler.requestAdditionalServerPages(
                syncDevice,
                targetIp,
                config.name,
                currentServerPage + 1,
                totalServerPages,
                SyncPaginationConfig.defaultNetworkPageSize,
                _isSyncCancelled,
              );
            }
          }

          // Determine if we should continue pagination
          hasMorePages = !paginatedData.isLastPage;

          if (!hasMorePages) {
            final serverMetadata = _serverPaginationHandler.getServerPaginationMetadata(config.name);
            final serverTotalPages = serverMetadata['totalPages'] ?? 0;
            if (serverTotalPages > 0 && pageIndex < serverTotalPages - 1) {
              hasMorePages = true;
              Logger.debug(
                  'Local data complete but server metadata indicates $serverTotalPages pages total. Continuing pagination for ${config.name}');
            }
          }

          pageIndex++;

          // Add delay between pages
          if (hasMorePages) {
            await Future.delayed(SyncPaginationConfig.batchDelay);

            if (_isSyncCancelled) {
              Logger.warning('Sync operation was cancelled during delay');
              return false;
            }
          }

          Logger.debug('Sent ${config.name} page ${pageIndex - 1}/${paginatedData.totalPages - 1}');
        } catch (e) {
          Logger.error('Error syncing ${config.name} page $pageIndex: $e');
          return false;
        }
      }

      if (_isSyncCancelled) {
        Logger.warning('Sync for ${config.name} was cancelled');
        return false;
      }

      Logger.debug('Completed paginated sync for ${config.name}');
      return true;
    } finally {
      _activeEntityTypes.remove(config.name);
    }
  }

  @override
  void updateProgress({
    required String currentEntity,
    required int currentPage,
    required int totalPages,
    required double progressPercentage,
    required int entitiesCompleted,
    required int totalEntities,
    required String operation,
  }) {
    _progressTracker.updateProgress(
      currentEntity: currentEntity,
      currentPage: currentPage,
      totalPages: totalPages,
      progressPercentage: progressPercentage,
      entitiesCompleted: entitiesCompleted,
      totalEntities: totalEntities,
      operation: operation,
    );
  }

  @override
  void resetProgress() {
    _progressTracker.resetProgress();
    _serverPaginationHandler.reset();
    _activeEntityTypes.clear();
    _isSyncCancelled = false;
    Logger.debug('Progress tracking reset (including pending response data)');
  }

  @override
  SyncProgress? getCurrentProgress(String entityType) {
    return _progressTracker.getCurrentProgress(entityType);
  }

  @override
  Map<String, int> getServerPaginationMetadata(String entityType) {
    return _serverPaginationHandler.getServerPaginationMetadata(entityType);
  }

  @override
  void updateServerPaginationMetadata(
    String entityType,
    int totalPages,
    int totalItems,
  ) {
    _serverPaginationHandler.updateServerPaginationMetadata(entityType, totalPages, totalItems);
  }

  @override
  double calculateOverallProgress() {
    return _progressTracker.calculateOverallProgress();
  }

  @override
  bool get isSyncInProgress => _activeEntityTypes.isNotEmpty;

  @override
  List<String> get activeEntityTypes => _activeEntityTypes.toList();

  @override
  int getLastSentServerPage(String deviceId, String entityType) {
    return _serverPaginationHandler.getLastSentServerPage(deviceId, entityType);
  }

  @override
  void setLastSentServerPage(String deviceId, String entityType, int page) {
    _serverPaginationHandler.setLastSentServerPage(deviceId, entityType, page);
  }

  @override
  Future<void> cancelSync() async {
    Logger.warning('Cancelling sync operations');
    _isSyncCancelled = true;
    _activeEntityTypes.clear();
    _progressTracker.addCancellationEvent();
  }

  @override
  Map<String, PaginatedSyncDataDto> getPendingResponseData() {
    return _serverPaginationHandler.getPendingResponseData();
  }

  @override
  void clearPendingResponseData() {
    _serverPaginationHandler.clearPendingResponseData();
  }

  @override
  void validateAndCleanStalePendingData() {
    _serverPaginationHandler.validateAndCleanStalePendingData();
  }

  String _getTargetIpFromSyncDevice(SyncDevice syncDevice) {
    final targetIp = syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
    Logger.debug('Selected target IP: $targetIp (fromIp: ${syncDevice.fromIp}, toIp: ${syncDevice.toIp})');
    return targetIp;
  }

  void dispose() {
    Logger.debug('Disposing SyncPaginationService and cleaning up state...');
    resetProgress();
    _progressTracker.dispose();
    Logger.debug('SyncPaginationService disposed successfully');
  }
}
