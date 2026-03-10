import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Handles bidirectional sync server pagination and pending response data
class ServerPaginationHandler {
  final ISyncCommunicationService _communicationService;

  // Server pagination tracking
  final Map<String, int> _serverTotalPages = {};
  final Map<String, int> _serverTotalItems = {};
  final Map<String, Map<String, int>> _serverLastSentPage = {}; // {deviceId: {entityType: lastSentPage}}

  // Pending response data from bidirectional sync
  final Map<String, PaginatedSyncDataDto> _pendingResponseData = {};

  ServerPaginationHandler(this._communicationService);

  Map<String, int> getServerPaginationMetadata(String entityType) {
    return {
      'totalPages': _serverTotalPages[entityType] ?? 0,
      'totalItems': _serverTotalItems[entityType] ?? 0,
    };
  }

  void updateServerPaginationMetadata(
    String entityType,
    int totalPages,
    int totalItems,
  ) {
    _serverTotalPages[entityType] = totalPages;
    _serverTotalItems[entityType] = totalItems;
    Logger.debug('Updated server pagination for $entityType: $totalPages pages, $totalItems items');
  }

  int getLastSentServerPage(String deviceId, String entityType) {
    return _serverLastSentPage[deviceId]?[entityType] ?? -1;
  }

  void setLastSentServerPage(String deviceId, String entityType, int page) {
    _serverLastSentPage.putIfAbsent(deviceId, () => {});
    _serverLastSentPage[deviceId]![entityType] = page;
    Logger.debug('Updated last sent server page for $deviceId/$entityType: $page');
  }

  Map<String, PaginatedSyncDataDto> getPendingResponseData() {
    Logger.info(
        'Retrieving ${_pendingResponseData.length} pending response DTOs: ${_pendingResponseData.keys.join(', ')}');
    return Map<String, PaginatedSyncDataDto>.from(_pendingResponseData);
  }

  void clearPendingResponseData() {
    final clearedCount = _pendingResponseData.length;
    _pendingResponseData.clear();
    Logger.debug('Cleared $clearedCount pending response data entries');
  }

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
        final syncTimestamp = data.syncDevice.createdDate;
        if (now.difference(syncTimestamp) > staleThreshold) {
          staleKeys.add(entityType);
          Logger.warning(
              'Found stale pending sync data for $entityType (${now.difference(syncTimestamp).inMinutes} minutes old)');
        }
      } catch (e) {
        staleKeys.add(entityType);
        Logger.warning('Found unvalidatable pending sync data for $entityType - marking as stale');
      }
    });

    // Remove stale entries
    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        _pendingResponseData.remove(key);
        Logger.debug('Removed stale pending data for $key');
      }
      Logger.info('Cleaned up ${staleKeys.length} stale pending sync data entries');
    }

    // Safety check: if too much pending data, clear all
    if (_pendingResponseData.length > 50) {
      Logger.warning(
          'Excessive pending response data (${_pendingResponseData.length} entries) - clearing all to prevent memory issues');
      _pendingResponseData.clear();
    }
  }

  void storePendingResponse(String entityType, PaginatedSyncDataDto responseData) {
    Logger.info('Storing ${responseData.entityType} response data');
    _pendingResponseData[entityType] = responseData;
  }

  void storeAdditionalServerPage(String entityType, int serverPage, PaginatedSyncDataDto responseData) {
    final existingData = _pendingResponseData[entityType];
    if (existingData != null) {
      Logger.info('Accumulating additional server page data for $entityType');
      _pendingResponseData['${entityType}_page_$serverPage'] = responseData;
    } else {
      _pendingResponseData[entityType] = responseData;
    }
  }

  /// Requests additional server pages for bidirectional sync
  Future<void> requestAdditionalServerPages(
    SyncDevice syncDevice,
    String targetIp,
    String entityType,
    int startServerPage,
    int totalServerPages,
    int pageSize,
    bool isCancelled,
  ) async {
    Logger.info('Requesting additional server pages for $entityType: pages $startServerPage-${totalServerPages - 1}');

    for (int serverPage = startServerPage; serverPage < totalServerPages; serverPage++) {
      if (isCancelled) {
        Logger.warning('Additional server page requests cancelled for $entityType');
        break;
      }

      try {
        Logger.info('Requesting $entityType server page $serverPage/$totalServerPages');

        // Create minimal DTO requesting specific server page
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
          requestedServerPage: serverPage,
        );

        final response = await _communicationService.sendPaginatedDataToDevice(targetIp, requestDto);

        if (!response.success) {
          Logger.error('Failed to request $entityType server page $serverPage: ${response.error}');
          break;
        }

        if (response.responseData != null) {
          Logger.info('Received additional $entityType server page $serverPage data');
          storeAdditionalServerPage(entityType, serverPage, response.responseData!);

          final hasMorePages = response.responseData!.hasMoreServerPages == true;
          if (!hasMorePages) {
            Logger.info('Completed requesting all server pages for $entityType');
            break;
          }
        }

        // Add delay between requests
        await Future.delayed(SyncPaginationConfig.batchDelay);
      } catch (e) {
        Logger.error('Error requesting $entityType server page $serverPage: $e');
        break;
      }
    }
  }

  void reset() {
    _serverTotalPages.clear();
    _serverTotalItems.clear();
    _serverLastSentPage.clear();
    _pendingResponseData.clear();
  }
}
