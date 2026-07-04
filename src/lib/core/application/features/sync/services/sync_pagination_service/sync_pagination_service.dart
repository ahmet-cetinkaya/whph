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

/// Result of syncing a single page
class _PageSyncResult {
  final bool success;
  final bool shouldBreak;
  final int lastReceivedServerPage;
  final int totalServerPages;
  final bool hasMorePages;
  final int totalPages;

  const _PageSyncResult({
    required this.success,
    required this.shouldBreak,
    required this.lastReceivedServerPage,
    required this.totalServerPages,
    required this.hasMorePages,
    required this.totalPages,
  });
}

/// Result of building and sending a page
class _BuildSendResult {
  final bool success;
  final SyncCommunicationResponse response;

  const _BuildSendResult({
    required this.success,
    required this.response,
  });
}

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
      int lastReceivedServerPage = -1;
      int totalServerPages = 0;

      Logger.info('Starting paginated sync for ${config.name}');
      Logger.info('Using sync date filter: $effectiveLastSyncDate');

      while (hasMorePages && !_isSyncCancelled) {
        try {
          final pageResult = await _syncNextPage(
            config: config,
            syncDevice: syncDevice,
            targetIp: targetIp,
            effectiveLastSyncDate: effectiveLastSyncDate,
            pageIndex: pageIndex,
            lastReceivedServerPage: lastReceivedServerPage,
            totalServerPages: totalServerPages,
          );

          if (!pageResult.success) {
            return false;
          }

          if (pageResult.shouldBreak) {
            break;
          }

          lastReceivedServerPage = pageResult.lastReceivedServerPage;
          totalServerPages = pageResult.totalServerPages;
          hasMorePages = pageResult.hasMorePages;

          pageIndex++;

          if (!await _awaitPageDelay(config.name)) {
            return false;
          }

          Logger.debug('Sent ${config.name} page ${pageIndex - 1}/${pageResult.totalPages - 1}');
        } catch (e) {
          Logger.error('Error syncing ${config.name} page $pageIndex: $e');
          return false;
        }
      }

      if (_isSyncCancelled) {
        Logger.warning('Sync for ${config.name} was cancelled');
        return false;
      }

      // Fetch any server pages not delivered during the lockstep above, in a single
      // sequential pass. This runs once per entity instead of once per local page.
      await _fetchRemainingServerPages(
        syncDevice: syncDevice,
        targetIp: targetIp,
        entityType: config.name,
        lastReceivedServerPage: lastReceivedServerPage,
        totalServerPages: totalServerPages,
      );

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

  /// Result of syncing a single page
  Future<_PageSyncResult> _syncNextPage({
    required PaginatedSyncConfig config,
    required SyncDevice syncDevice,
    required String targetIp,
    required DateTime effectiveLastSyncDate,
    required int pageIndex,
    required int lastReceivedServerPage,
    required int totalServerPages,
  }) async {
    _updateFetchingProgress(config, pageIndex);

    Logger.info(
        'Fetching ${config.name} data (page $pageIndex, pageSize: ${SyncPaginationConfig.defaultNetworkPageSize}, lastSync: $effectiveLastSyncDate)');

    final paginatedData = await config.getPaginatedSyncData(
      effectiveLastSyncDate,
      pageIndex,
      SyncPaginationConfig.defaultNetworkPageSize,
      config.name,
    );

    Logger.info(
        '${config.name} page $pageIndex: ${paginatedData.data.getTotalItemCount()} items, totalPages: ${paginatedData.totalPages}, isLastPage: ${paginatedData.isLastPage}');

    _updateTransmittingProgress(config, pageIndex, paginatedData.totalPages);

    final itemCount = paginatedData.data.getTotalItemCount();
    if (itemCount == 0 && pageIndex > 0) {
      Logger.info('Skipping empty ${config.name} page $pageIndex - no data to send');
      return const _PageSyncResult(
        success: true,
        shouldBreak: true,
        lastReceivedServerPage: -1,
        totalServerPages: 0,
        hasMorePages: false,
        totalPages: 1,
      );
    }

    final sendResult = await _buildAndSendPage(
      config,
      syncDevice,
      targetIp,
      paginatedData,
      pageIndex,
    );

    if (!sendResult.success) {
      return const _PageSyncResult(
        success: false,
        shouldBreak: false,
        lastReceivedServerPage: -1,
        totalServerPages: 0,
        hasMorePages: false,
        totalPages: 1,
      );
    }

    final trackResult = _handleServerResponse(
      config.name,
      sendResult.response,
      lastReceivedServerPage,
      totalServerPages,
    );

    return _PageSyncResult(
      success: true,
      shouldBreak: false,
      lastReceivedServerPage: trackResult.lastReceivedServerPage,
      totalServerPages: trackResult.totalServerPages,
      hasMorePages: !paginatedData.isLastPage,
      totalPages: paginatedData.totalPages,
    );
  }

  void _updateFetchingProgress(PaginatedSyncConfig config, int pageIndex) {
    _progressTracker.updateProgress(
      currentEntity: config.name,
      currentPage: pageIndex,
      totalPages: -1,
      progressPercentage: 0.0,
      entitiesCompleted: 0,
      totalEntities: _configurationService.getAllConfigurations().length,
      operation: 'fetching',
    );
  }

  void _updateTransmittingProgress(PaginatedSyncConfig config, int pageIndex, int totalPages) {
    final entityProgress = totalPages > 0 ? ((pageIndex + 1) / totalPages * 100) : 100.0;
    _progressTracker.updateProgress(
      currentEntity: config.name,
      currentPage: pageIndex,
      totalPages: totalPages,
      progressPercentage: entityProgress,
      entitiesCompleted: 0,
      totalEntities: _configurationService.getAllConfigurations().length,
      operation: 'transmitting',
    );
  }

  Future<bool> _awaitPageDelay(String entityType) async {
    await Future.delayed(SyncPaginationConfig.batchDelay);
    if (_isSyncCancelled) {
      Logger.warning('Sync operation was cancelled during delay');
      return false;
    }
    return true;
  }

  Future<_BuildSendResult> _buildAndSendPage(
    PaginatedSyncConfig config,
    SyncDevice syncDevice,
    String targetIp,
    PaginatedSyncData paginatedData,
    int pageIndex,
  ) async {
    final progress = _progressTracker.getCurrentProgress(config.name);
    final dto = _dtoBuilder.buildDto(
      syncDevice: syncDevice,
      paginatedData: paginatedData,
      entityType: config.name,
      progress: progress,
    );

    final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
    if (!response.success) {
      Logger.error('Failed to send ${config.name} page $pageIndex: ${response.error}');
      return _BuildSendResult(success: false, response: response);
    }

    return _BuildSendResult(success: true, response: response);
  }

  ({
    int lastReceivedServerPage,
    int totalServerPages,
  }) _handleServerResponse(
    String entityType,
    SyncCommunicationResponse response,
    int lastReceivedServerPage,
    int totalServerPages,
  ) {
    if (response.isComplete || response.responseData == null) {
      return (lastReceivedServerPage: lastReceivedServerPage, totalServerPages: totalServerPages);
    }

    return _trackServerPageProgress(
      entityType,
      response.responseData!,
      lastReceivedServerPage: lastReceivedServerPage,
      totalServerPages: totalServerPages,
    );
  }

  String _getTargetIpFromSyncDevice(SyncDevice syncDevice) {
    final targetIp = syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
    Logger.debug('Selected target IP: $targetIp (fromIp: ${syncDevice.fromIp}, toIp: ${syncDevice.toIp})');
    return targetIp;
  }

  /// Stores a lockstep server response and tracks the highest server page received
  /// and the total server pages reported, for later single-pass fetching.
  ({
    int lastReceivedServerPage,
    int totalServerPages,
  }) _trackServerPageProgress(
    String entityType,
    PaginatedSyncDataDto responseData, {
    required int lastReceivedServerPage,
    required int totalServerPages,
  }) {
    Logger.info('Server has data to send back for $entityType - storing for later processing');

    final currentServerPage = responseData.currentServerPage ?? lastReceivedServerPage;

    if (currentServerPage >= 0) {
      _serverPaginationHandler.storeAdditionalServerPage(entityType, currentServerPage, responseData);
    } else {
      _serverPaginationHandler.storePendingResponse(entityType, responseData);
    }
    final responseTotalServerPages = responseData.totalServerPages ?? totalServerPages;

    final newLastReceived = currentServerPage > lastReceivedServerPage ? currentServerPage : lastReceivedServerPage;

    // Clamp to a sane maximum to guard against malformed remote responses
    const maxPages = 50000;
    final newTotal =
        (responseTotalServerPages > totalServerPages ? responseTotalServerPages : totalServerPages).clamp(0, maxPages);

    return (
      lastReceivedServerPage: newLastReceived,
      totalServerPages: newTotal,
    );
  }

  /// Fetches any server pages not delivered during the lockstep loop, in a single
  /// sequential pass. Runs once per entity instead of once per local page.
  Future<void> _fetchRemainingServerPages({
    required SyncDevice syncDevice,
    required String targetIp,
    required String entityType,
    required int lastReceivedServerPage,
    required int totalServerPages,
  }) async {
    if (_isSyncCancelled || totalServerPages <= 0 || lastReceivedServerPage >= totalServerPages - 1) {
      return;
    }

    final startServerPage = lastReceivedServerPage + 1;
    Logger.info('Fetching remaining server pages for $entityType: pages $startServerPage-${totalServerPages - 1}');
    await _serverPaginationHandler.requestAdditionalServerPages(
      syncDevice,
      targetIp,
      entityType,
      startServerPage,
      totalServerPages,
      SyncPaginationConfig.defaultNetworkPageSize,
      _isSyncCancelled,
    );
  }

  void dispose() {
    Logger.debug('Disposing SyncPaginationService and cleaning up state...');
    resetProgress();
    _progressTracker.dispose();
    Logger.debug('SyncPaginationService disposed successfully');
  }
}
