import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Implementation of sync pagination service
class SyncPaginationService implements ISyncPaginationService {
  final ISyncCommunicationService _communicationService;
  final ISyncConfigurationService _configurationService;

  // Progress tracking
  final _progressController = StreamController<SyncProgress>.broadcast();
  final Map<String, SyncProgress> _currentProgress = {};

  // Server pagination tracking for dynamic pagination control
  final Map<String, int> _serverTotalPages = {};
  final Map<String, int> _serverTotalItems = {};

  // Server pagination tracking for bidirectional sync to track which page was last sent per entity
  final Map<String, Map<String, int>> _serverLastSentPage = {}; // {deviceId: {entityType: lastSentPage}}

  // Active sync state
  final Set<String> _activeEntityTypes = <String>{};
  bool _isSyncCancelled = false;

  // Store response data from bidirectional sync for processing by command
  final Map<String, PaginatedSyncDataDto> _pendingResponseData = {};

  SyncPaginationService({
    required ISyncCommunicationService communicationService,
    required ISyncConfigurationService configurationService,
  })  : _communicationService = communicationService,
        _configurationService = configurationService;

  @override
  Stream<SyncProgress> get progressStream => _progressController.stream;

  @override
  Future<bool> syncEntityWithPagination(
    PaginatedSyncConfig config,
    SyncDevice syncDevice,
    DateTime lastSyncDate, {
    String? targetDeviceId,
    Future<void> Function(PaginatedSyncDataDto pageData)? onPageReceived,
  }) async {
    if (_isSyncCancelled) {
      Logger.warning('⚠️ Sync operation was cancelled');
      return false;
    }

    // Determine target IP - use sync device's IP for communication
    final String targetIp = _getTargetIpFromSyncDevice(syncDevice);
    Logger.debug('🎯 Using target IP: $targetIp for ${config.name} sync with device ${syncDevice.id}');

    if (targetIp.isEmpty) {
      Logger.error('❌ Could not determine target IP address from sync device ${syncDevice.id}');
      return false;
    }

    _activeEntityTypes.add(config.name);

    try {
      final DateTime effectiveLastSyncDate = lastSyncDate;
      int pageIndex = 0;
      bool hasMorePages = true;

      Logger.info('🔄 Starting paginated sync for ${config.name}');
      Logger.info('📅 Using sync date filter: $effectiveLastSyncDate');

      while (hasMorePages && !_isSyncCancelled) {
        try {
          updateProgress(
            currentEntity: config.name,
            currentPage: pageIndex,
            totalPages: -1, // Unknown until first page
            progressPercentage: 0.0,
            entitiesCompleted: 0,
            totalEntities: _configurationService.getAllConfigurations().length,
            operation: 'fetching',
          );

          Logger.info(
              '🔍 Fetching ${config.name} data (page $pageIndex, pageSize: ${SyncPaginationConfig.defaultNetworkPageSize}, lastSync: $effectiveLastSyncDate)');

          // Get paginated data for this entity
          final paginatedData = await config.getPaginatedSyncData(
            effectiveLastSyncDate,
            pageIndex,
            SyncPaginationConfig.defaultNetworkPageSize,
            config.name,
          );

          Logger.info(
              '📊 ${config.name} page $pageIndex: ${paginatedData.data.getTotalItemCount()} items, totalPages: ${paginatedData.totalPages}, isLastPage: ${paginatedData.isLastPage}');
          Logger.info(
              '📋 ${config.name} page $pageIndex details: totalItems=${paginatedData.totalItems}, pageSize=${paginatedData.pageSize}');

          // Update progress with actual page info
          final entityProgress =
              paginatedData.totalPages > 0 ? ((pageIndex + 1) / paginatedData.totalPages * 100) : 100.0;
          updateProgress(
            currentEntity: config.name,
            currentPage: pageIndex,
            totalPages: paginatedData.totalPages,
            progressPercentage: entityProgress,
            entitiesCompleted: 0,
            totalEntities: _configurationService.getAllConfigurations().length,
            operation: 'transmitting',
          );

          // Always send sync request for bidirectional sync, even if local device has no data
          // This ensures the remote device can send its data back
          if (paginatedData.totalItems == 0) {
            Logger.debug('📤 Sending empty sync request for ${config.name} to receive remote data');
          }

          // Skip sending empty pages (optimization)
          final itemCount = paginatedData.data.getTotalItemCount();
          if (itemCount == 0 && pageIndex > 0) {
            Logger.info('⏭️ Skipping empty ${config.name} page $pageIndex - no data to send');
            break;
          }

          // Create DTO for this page
          final dto = _createPaginatedSyncDataDto(syncDevice, paginatedData, config.name);

          // Send this page to the remote device
          final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
          if (!response.success) {
            Logger.error('❌ Failed to send ${config.name} page $pageIndex: ${response.error}');
            return false;
          }

          // Check if server indicates bidirectional sync is needed
          if (!response.isComplete) {
            Logger.info('🔄 Server has data to send back for ${config.name}');

            // Store server response data for processing by the command handler
            if (response.responseData != null) {
              Logger.info('📨 Server response data received for ${config.name}');

              // If callback is provided, process immediately and DO NOT store in pendingResponseData
              if (onPageReceived != null) {
                Logger.info('⚡ Processing ${config.name} response data immediately via callback');
                await onPageReceived(response.responseData!);
              } else {
                // Legacy behavior: Store for later processing
                Logger.info('🔍 Storing ${config.name} response data for later processing');
                _pendingResponseData[config.name] = response.responseData!;
              }

              // Check if server has more pages to send for bidirectional sync
              final responseData = response.responseData!;
              if (responseData.hasMoreServerPages == true) {
                final currentServerPage = responseData.currentServerPage ?? 0;
                final totalServerPages = responseData.totalServerPages ?? 1;

                Logger.info(
                    '🔄 Server has more pages for ${config.name} (page ${currentServerPage + 1}/$totalServerPages)');

                // Continue requesting server pages for bidirectional sync
                await _requestAdditionalServerPages(
                  syncDevice,
                  targetIp,
                  config.name,
                  currentServerPage + 1,
                  totalServerPages,
                  SyncPaginationConfig.defaultNetworkPageSize,
                  onPageReceived: onPageReceived, // Pass the callback
                );
              }
            } else {
              Logger.warning('⚠️ Server indicated it has data but no response data received for ${config.name}');
            }
          }

          // Determine if we should continue pagination
          hasMorePages = !paginatedData.isLastPage;

          // Critical fix: Don't continue pagination based only on server response
          // The server response is for bidirectional sync, not for continuing client pagination
          // We should only continue if the local data indicates more pages
          if (!hasMorePages) {
            // Only check server metadata for additional pages, not server response isComplete status
            final serverTotalPages = _serverTotalPages[config.name];
            if (serverTotalPages != null && pageIndex < serverTotalPages - 1) {
              hasMorePages = true;
              Logger.debug(
                  '🔄 Local data complete but server metadata indicates $serverTotalPages pages total. Continuing pagination for ${config.name} (page $pageIndex)');
            }
          }

          pageIndex++;

          // Add delay between pages
          if (hasMorePages) {
            await Future.delayed(SyncPaginationConfig.batchDelay);

            // Check for cancellation after the delay
            if (_isSyncCancelled) {
              Logger.warning('⚠️ Sync operation was cancelled during delay');
              return false;
            }
          }

          Logger.debug('✅ Sent ${config.name} page ${pageIndex - 1}/${paginatedData.totalPages - 1}');
        } catch (e) {
          Logger.error('❌ Error syncing ${config.name} page $pageIndex: $e');
          return false;
        }
      }

      if (_isSyncCancelled) {
        Logger.warning('⚠️ Sync for ${config.name} was cancelled');
        return false;
      }

      Logger.debug('✅ Completed paginated sync for ${config.name}');
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
    final progress = SyncProgress(
      currentEntity: currentEntity,
      currentPage: currentPage,
      totalPages: totalPages,
      progressPercentage: progressPercentage.clamp(0.0, 100.0),
      entitiesCompleted: entitiesCompleted,
      totalEntities: totalEntities,
      operation: operation,
    );

    _currentProgress[currentEntity] = progress;
    _progressController.add(progress);

    Logger.debug(
        '📊 Progress: ${progress.progressPercentage.toStringAsFixed(1)}% - $operation $currentEntity (page ${currentPage + 1}/$totalPages)');
  }

  @override
  void resetProgress() {
    _currentProgress.clear();
    _serverTotalPages.clear();
    _serverTotalItems.clear();
    _serverLastSentPage.clear(); // Clear the server page tracking
    _activeEntityTypes.clear();
    _isSyncCancelled = false;
    _pendingResponseData.clear(); // Clear stale pending response data
    Logger.debug('🔄 Progress tracking reset (including pending response data)');
  }

  @override
  SyncProgress? getCurrentProgress(String entityType) {
    return _currentProgress[entityType];
  }

  @override
  Map<String, int> getServerPaginationMetadata(String entityType) {
    return {
      'totalPages': _serverTotalPages[entityType] ?? 0,
      'totalItems': _serverTotalItems[entityType] ?? 0,
    };
  }

  @override
  void updateServerPaginationMetadata(
    String entityType,
    int totalPages,
    int totalItems,
  ) {
    _serverTotalPages[entityType] = totalPages;
    _serverTotalItems[entityType] = totalItems;
    Logger.debug('📊 Updated server pagination for $entityType: $totalPages pages, $totalItems items');
  }

  @override
  double calculateOverallProgress() {
    if (_currentProgress.isEmpty) return 0.0;

    final totalConfigs = _configurationService.getAllConfigurations().length;
    if (totalConfigs == 0) return 100.0;

    double totalProgress = 0.0;
    int completedEntities = 0;

    for (final config in _configurationService.getAllConfigurations()) {
      final progress = _currentProgress[config.name];
      if (progress != null) {
        if (progress.progressPercentage >= 100.0) {
          completedEntities++;
        } else {
          totalProgress += progress.progressPercentage / 100.0;
        }
      }
    }

    final overallProgress = ((completedEntities + totalProgress) / totalConfigs * 100);
    return overallProgress.clamp(0.0, 100.0);
  }

  @override
  bool get isSyncInProgress => _activeEntityTypes.isNotEmpty;

  @override
  List<String> get activeEntityTypes => _activeEntityTypes.toList();

  @override
  int getLastSentServerPage(String deviceId, String entityType) {
    return _serverLastSentPage[deviceId]?[entityType] ?? -1;
  }

  @override
  void setLastSentServerPage(String deviceId, String entityType, int page) {
    _serverLastSentPage.putIfAbsent(deviceId, () => {});
    _serverLastSentPage[deviceId]![entityType] = page;
    Logger.debug('📊 Updated last sent server page for $deviceId/$entityType: $page');
  }

  @override
  Future<void> cancelSync() async {
    Logger.warning('⚠️ Cancelling sync operations');
    _isSyncCancelled = true;
    _activeEntityTypes.clear();

    // Add cancellation progress event
    final cancelProgress = SyncProgress(
      currentEntity: 'system',
      currentPage: 0,
      totalPages: 1,
      progressPercentage: 0.0,
      entitiesCompleted: 0,
      totalEntities: 0,
      operation: 'cancelled',
    );
    _progressController.add(cancelProgress);
  }

  // Private helper methods

  String _getTargetIpFromSyncDevice(SyncDevice syncDevice) {
    // For sync communication, we need to send data TO the remote device
    // So we use the fromIp (remote device's IP) as the target
    final targetIp = syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
    Logger.debug('🎯 Selected target IP: $targetIp (fromIp: ${syncDevice.fromIp}, toIp: ${syncDevice.toIp})');
    return targetIp;
  }

  PaginatedSyncDataDto _createPaginatedSyncDataDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    String entityType,
  ) {
    // Create progress info
    final progress = _currentProgress[entityType];

    Logger.debug('🔧 Creating DTO for $entityType with isDebugMode: $kDebugMode');

    // Create DTO based on entity type
    // This is a simplified implementation - in reality, you'd need to handle all entity types
    switch (entityType) {
      case 'AppUsage':
        final appUsagesData = paginatedData.data.getTotalItemCount() > 0 ? paginatedData as dynamic : null;
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          appUsagesSyncData: appUsagesData,
        );

      case 'Task':
        final itemCount = paginatedData.data.getTotalItemCount();
        Logger.debug('🔧 SERVICE Task DTO - ENTRY: itemCount=$itemCount, totalItems=${paginatedData.totalItems}');
        Logger.debug(
            '🔧 SERVICE Task DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}');

        final paginatedSyncData = paginatedData as PaginatedSyncData<Task>;
        final tasksData = itemCount > 0 ? paginatedSyncData : null;
        Logger.debug('🔧 SERVICE Task DTO - tasksData is null: ${tasksData == null}');

        final dto = PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          tasksSyncData: tasksData,
        );

        Logger.debug('🔧 Final Task DTO - tasksSyncData is null: ${dto.tasksSyncData == null}');
        return dto;

      case 'Habit':
        final itemCount = paginatedData.data.getTotalItemCount();
        Logger.debug('🔧 Habit DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
        Logger.debug(
            '🔧 Habit DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

        final paginatedSyncData = paginatedData as PaginatedSyncData<Habit>;
        final habitsData = itemCount > 0 ? paginatedSyncData : null;
        Logger.debug('🔧 Habit DTO - habitsData is null: ${habitsData == null}');

        if (habitsData != null) {
          Logger.debug(
              '🔧 Habit DTO - sample habit IDs: ${habitsData.data.createSync.take(3).map((h) => h.id).toList()}');
        }

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          habitsSyncData: habitsData,
        );

      case 'HabitRecord':
        final itemCount = paginatedData.data.getTotalItemCount();
        Logger.debug('🔧 HabitRecord DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
        Logger.debug(
            '🔧 HabitRecord DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

        final habitRecordsData = itemCount > 0 ? paginatedData as dynamic : null;
        Logger.debug('🔧 HabitRecord DTO - habitRecordsData is null: ${habitRecordsData == null}');

        if (habitRecordsData != null) {
          Logger.debug(
              '🔧 HabitRecord DTO - sample record IDs: ${habitRecordsData.data.createSync.take(3).map((r) => r.id).toList()}');
        }

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          habitRecordsSyncData: habitRecordsData,
        );

      case 'HabitTag':
        final itemCount = paginatedData.data.getTotalItemCount();
        Logger.debug('🔧 HabitTag DTO creation - itemCount: $itemCount, totalItems: ${paginatedData.totalItems}');
        Logger.debug(
            '🔧 HabitTag DTO - createSync: ${paginatedData.data.createSync.length}, updateSync: ${paginatedData.data.updateSync.length}, deleteSync: ${paginatedData.data.deleteSync.length}');

        final habitTagsData = itemCount > 0 ? paginatedData as dynamic : null;
        Logger.debug('🔧 HabitTag DTO - habitTagsData is null: ${habitTagsData == null}');

        if (habitTagsData != null) {
          Logger.debug(
              '🔧 HabitTag DTO - sample tag IDs: ${habitTagsData.data.createSync.take(3).map((t) => t.id).toList()}');
        }

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          habitTagsSyncData: habitTagsData,
        );

      case 'SyncDevice':
        // Ensure proper typing for SyncDevice data
        final syncDeviceData = paginatedData.data.getTotalItemCount() > 0 ? paginatedData as dynamic : null;
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          syncDevicesSyncData: syncDeviceData,
        );

      // Add other entity types as needed
      default:
        Logger.debug('🔧 Default case triggered for entity type: $entityType');

        // Warn if this is a habit-related entity to catch potential issues
        if (entityType.contains('Habit')) {
          Logger.warning(
              '⚠️ Habit-related entity $entityType fell through to default case - this may indicate missing explicit handling');
        }

        // Generic implementation for other entity types
        // Set appropriate sync data field based on entity type
        final hasData = paginatedData.data.getTotalItemCount() > 0;
        Logger.debug('🔧 Default case - hasData: $hasData, itemCount: ${paginatedData.data.getTotalItemCount()}');

        // Use dynamic casting for runtime type flexibility
        final syncDataDynamic = hasData ? paginatedData as dynamic : null;
        Logger.debug('🔧 Default case - syncDataDynamic is null: ${syncDataDynamic == null}');

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: paginatedData.pageIndex,
          pageSize: paginatedData.pageSize,
          totalPages: paginatedData.totalPages,
          totalItems: paginatedData.totalItems,
          isLastPage: paginatedData.isLastPage,
          progress: progress,
          // Set the appropriate field based on entity type with dynamic casting
          appUsagesSyncData: entityType == 'AppUsage' ? syncDataDynamic : null,
          appUsageTagsSyncData: entityType == 'AppUsageTag' ? syncDataDynamic : null,
          appUsageTimeRecordsSyncData: entityType == 'AppUsageTimeRecord' ? syncDataDynamic : null,
          appUsageTagRulesSyncData: entityType == 'AppUsageTagRule' ? syncDataDynamic : null,
          appUsageIgnoreRulesSyncData: entityType == 'AppUsageIgnoreRule' ? syncDataDynamic : null,
          habitsSyncData: entityType == 'Habit' ? syncDataDynamic : null,
          habitRecordsSyncData: entityType == 'HabitRecord' ? syncDataDynamic : null,
          habitTagsSyncData: entityType == 'HabitTag' ? syncDataDynamic : null,
          tagsSyncData: entityType == 'Tag' ? syncDataDynamic : null,
          tagTagsSyncData: entityType == 'TagTag' ? syncDataDynamic : null,
          tasksSyncData: entityType == 'Task' ? syncDataDynamic : null,
          taskTagsSyncData: entityType == 'TaskTag' ? syncDataDynamic : null,
          taskTimeRecordsSyncData: entityType == 'TaskTimeRecord' ? syncDataDynamic : null,
          settingsSyncData: entityType == 'Setting' ? syncDataDynamic : null,
          syncDevicesSyncData: entityType == 'SyncDevice' ? syncDataDynamic : null,
          notesSyncData: entityType == 'Note' ? syncDataDynamic : null,
          noteTagsSyncData: entityType == 'NoteTag' ? syncDataDynamic : null,
        );
    }
  }

  /// Gets all pending response data from bidirectional sync operations
  @override
  Map<String, PaginatedSyncDataDto> getPendingResponseData() {
    Logger.info(
        '📋 Retrieving ${_pendingResponseData.length} pending response DTOs: ${_pendingResponseData.keys.join(', ')}');
    return Map<String, PaginatedSyncDataDto>.from(_pendingResponseData);
  }

  /// Clears all pending response data (should be called after processing)
  @override
  void clearPendingResponseData() {
    final clearedCount = _pendingResponseData.length;
    _pendingResponseData.clear();
    Logger.debug('🧹 Cleared $clearedCount pending response data entries');
  }

  /// Validates and cleans up stale pending response data
  /// This should be called periodically to prevent memory leaks from orphaned data
  @override
  void validateAndCleanStalePendingData() {
    if (_pendingResponseData.isEmpty) {
      return;
    }

    final staleKeys = <String>[];
    final now = DateTime.now();

    // Check for stale pending data (older than 10 minutes)
    const staleThreshold = Duration(minutes: 10);

    _pendingResponseData.forEach((entityType, data) {
      try {
        // Check if the data has a timestamp we can validate
        final syncTimestamp = data.syncDevice.createdDate;
        if (now.difference(syncTimestamp) > staleThreshold) {
          staleKeys.add(entityType);
          Logger.warning(
              '⚠️ Found stale pending sync data for $entityType (${now.difference(syncTimestamp).inMinutes} minutes old)');
        }
      } catch (e) {
        // If we can't validate the timestamp, consider it stale
        staleKeys.add(entityType);
        Logger.warning('⚠️ Found unvalidatable pending sync data for $entityType - marking as stale');
      }
    });

    // Remove stale entries
    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        _pendingResponseData.remove(key);
        Logger.debug('🧹 Removed stale pending data for $key');
      }
      Logger.info('🧹 Cleaned up ${staleKeys.length} stale pending sync data entries');
    }

    // Additional safety check: if we have too much pending data, clear it all
    if (_pendingResponseData.length > 50) {
      Logger.warning(
          '⚠️ Excessive pending response data (${_pendingResponseData.length} entries) - clearing all to prevent memory issues');
      _pendingResponseData.clear();
    }
  }

  /// Requests additional server pages for bidirectional sync
  Future<void> _requestAdditionalServerPages(
    SyncDevice syncDevice,
    String targetIp,
    String entityType,
    int startServerPage,
    int totalServerPages,
    int pageSize, {
    Future<void> Function(PaginatedSyncDataDto pageData)? onPageReceived,
  }) async {
    Logger.info(
        '🔄 Requesting additional server pages for $entityType: pages $startServerPage-${totalServerPages - 1}');

    for (int serverPage = startServerPage; serverPage < totalServerPages; serverPage++) {
      try {
        Logger.info('📨 Requesting $entityType server page $serverPage/$totalServerPages');

        // Create a minimal DTO requesting specific server page
        final requestDto = PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: -1, // Indicates no client data
          pageSize: pageSize,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          requestedServerPage: serverPage, // Request specific server page
        );

        // Send request for specific server page
        final response = await _communicationService.sendPaginatedDataToDevice(targetIp, requestDto);

        if (!response.success) {
          Logger.error('❌ Failed to request $entityType server page $serverPage: ${response.error}');
          break;
        }

        // Store the additional server response data
        if (response.responseData != null) {
          Logger.info('📨 Received additional $entityType server page $serverPage data');

          if (onPageReceived != null) {
            Logger.info('⚡ Processing additional $entityType page $serverPage immediately via callback');
            await onPageReceived(response.responseData!);
          } else {
            // Store alongside existing data for this entity type
            // The command handler will process all accumulated data together
            final existingData = _pendingResponseData[entityType];
            if (existingData != null) {
              // We have multiple pages - the command handler will need to merge them
              Logger.info('🔗 Accumulating additional server page data for $entityType');
              _pendingResponseData['${entityType}_page_$serverPage'] = response.responseData!;
            } else {
              _pendingResponseData[entityType] = response.responseData!;
            }
          }

          // Check if this was the last page
          final hasMorePages = response.responseData!.hasMoreServerPages == true;
          if (!hasMorePages) {
            Logger.info('✅ Completed requesting all server pages for $entityType');
            break;
          }
        }

        // Add delay between requests
        await Future.delayed(SyncPaginationConfig.batchDelay);

        // Check for cancellation
        if (_isSyncCancelled) {
          Logger.warning('⚠️ Additional server page requests cancelled for $entityType');
          break;
        }
      } catch (e) {
        Logger.error('❌ Error requesting $entityType server page $serverPage: $e');
        break;
      }
    }
  }

  void dispose() {
    Logger.debug('🗑️ Disposing SyncPaginationService and cleaning up state...');

    // Clear all state to prevent memory leaks and stale data
    resetProgress();

    // Close the progress stream controller
    _progressController.close();

    Logger.debug('✅ SyncPaginationService disposed successfully');
  }
}
