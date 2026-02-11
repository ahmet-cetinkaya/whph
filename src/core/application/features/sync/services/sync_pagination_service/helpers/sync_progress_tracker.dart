import 'dart:async';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:domain/shared/utils/logger.dart';

/// Tracks and manages sync progress state and notifications
class SyncProgressTracker {
  final ISyncConfigurationService _configurationService;
  final _progressController = StreamController<SyncProgress>.broadcast();
  final Map<String, SyncProgress> _currentProgress = {};

  SyncProgressTracker(this._configurationService);

  Stream<SyncProgress> get progressStream => _progressController.stream;

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

    DomainLogger.debug(
        'Progress: ${progress.progressPercentage.toStringAsFixed(1)}% - $operation $currentEntity (page ${currentPage + 1}/$totalPages)');
  }

  void resetProgress() {
    _currentProgress.clear();
    DomainLogger.debug('Progress tracking reset');
  }

  SyncProgress? getCurrentProgress(String entityType) {
    return _currentProgress[entityType];
  }

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

  void addCancellationEvent() {
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

  void dispose() {
    _progressController.close();
  }
}
