import 'dart:async';
import 'package:whph/core/application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Service for tracking bidirectional sync progress across entities and devices.
class SyncProgressTracker {
  final _bidirectionalProgressController = StreamController<BidirectionalSyncProgress>.broadcast();
  Stream<BidirectionalSyncProgress> get bidirectionalProgressStream => _bidirectionalProgressController.stream;

  final Map<String, BidirectionalSyncProgress> _entityProgressMap = {};
  final Map<String, Set<String>> _deviceProgressMap = {};

  /// Update bidirectional sync progress for an entity/device combination.
  void updateProgress(BidirectionalSyncProgress progress) {
    final key = progress.key;
    _entityProgressMap[key] = progress;

    // Track devices per entity
    _deviceProgressMap[progress.entityType] ??= <String>{};
    _deviceProgressMap[progress.entityType]!.add(progress.deviceId);

    // Emit progress update
    _bidirectionalProgressController.add(progress);

    Logger.debug('Bidirectional progress updated: ${progress.statusDescription}');
  }

  /// Get progress by key (entityType_deviceId).
  BidirectionalSyncProgress? getProgress(String key) => _entityProgressMap[key];

  /// Set progress directly by key.
  void setProgress(String key, BidirectionalSyncProgress progress) {
    _entityProgressMap[key] = progress;
  }

  /// Calculate overall sync progress across all entities and devices.
  OverallSyncProgress calculateOverallProgress() {
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

  /// Reset all progress tracking.
  void reset() {
    _entityProgressMap.clear();
    _deviceProgressMap.clear();
  }

  /// Dispose resources.
  void dispose() {
    _bidirectionalProgressController.close();
  }
}
