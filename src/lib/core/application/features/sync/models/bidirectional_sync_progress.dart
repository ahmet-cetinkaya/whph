import 'package:dart_json_mapper/dart_json_mapper.dart';

/// Enhanced progress tracking model for bidirectional sync operations
@jsonSerializable
class BidirectionalSyncProgress {
  /// Entity type being synchronized
  final String entityType;

  /// Current device ID being processed
  final String deviceId;

  /// Direction of sync - 'outgoing', 'incoming', or 'complete'
  final SyncDirection direction;

  /// Phase of sync - 'validation', 'transmission', 'processing', 'complete'
  final SyncPhase phase;

  /// Current page being processed (0-based)
  final int currentPage;

  /// Total pages for this entity/device combination
  final int totalPages;

  /// Items processed in current batch
  final int itemsProcessed;

  /// Total items expected for this entity/device
  final int totalItems;

  /// Overall progress percentage for this entity/device (0-100)
  final double progressPercentage;

  /// Number of conflicts resolved during sync
  final int conflictsResolved;

  /// Error messages if any occurred
  final List<String> errorMessages;

  /// Timestamp of this progress update
  final DateTime timestamp;

  /// Whether this entity/device sync is complete
  final bool isComplete;

  /// Additional metadata for debugging and monitoring
  final Map<String, dynamic> metadata;

  BidirectionalSyncProgress({
    required this.entityType,
    required this.deviceId,
    required this.direction,
    required this.phase,
    this.currentPage = 0,
    this.totalPages = 1,
    this.itemsProcessed = 0,
    this.totalItems = 0,
    this.progressPercentage = 0.0,
    this.conflictsResolved = 0,
    this.errorMessages = const [],
    DateTime? timestamp,
    this.isComplete = false,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated values
  BidirectionalSyncProgress copyWith({
    String? entityType,
    String? deviceId,
    SyncDirection? direction,
    SyncPhase? phase,
    int? currentPage,
    int? totalPages,
    int? itemsProcessed,
    int? totalItems,
    double? progressPercentage,
    int? conflictsResolved,
    List<String>? errorMessages,
    DateTime? timestamp,
    bool? isComplete,
    Map<String, dynamic>? metadata,
  }) {
    return BidirectionalSyncProgress(
      entityType: entityType ?? this.entityType,
      deviceId: deviceId ?? this.deviceId,
      direction: direction ?? this.direction,
      phase: phase ?? this.phase,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      itemsProcessed: itemsProcessed ?? this.itemsProcessed,
      totalItems: totalItems ?? this.totalItems,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      conflictsResolved: conflictsResolved ?? this.conflictsResolved,
      errorMessages: errorMessages ?? this.errorMessages,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create progress for outgoing sync start
  factory BidirectionalSyncProgress.outgoingStart({
    required String entityType,
    required String deviceId,
    int totalPages = 1,
    int totalItems = 0,
    Map<String, dynamic>? metadata,
  }) {
    return BidirectionalSyncProgress(
      entityType: entityType,
      deviceId: deviceId,
      direction: SyncDirection.outgoing,
      phase: SyncPhase.transmission,
      totalPages: totalPages,
      totalItems: totalItems,
      metadata: metadata ?? {},
    );
  }

  /// Create progress for incoming sync start
  factory BidirectionalSyncProgress.incomingStart({
    required String entityType,
    required String deviceId,
    int totalItems = 0,
    Map<String, dynamic>? metadata,
  }) {
    return BidirectionalSyncProgress(
      entityType: entityType,
      deviceId: deviceId,
      direction: SyncDirection.incoming,
      phase: SyncPhase.processing,
      totalItems: totalItems,
      metadata: metadata ?? {},
    );
  }

  /// Create progress for completed sync
  factory BidirectionalSyncProgress.completed({
    required String entityType,
    required String deviceId,
    required int itemsProcessed,
    int conflictsResolved = 0,
    List<String> errorMessages = const [],
    Map<String, dynamic>? metadata,
  }) {
    return BidirectionalSyncProgress(
      entityType: entityType,
      deviceId: deviceId,
      direction: SyncDirection.complete,
      phase: SyncPhase.complete,
      itemsProcessed: itemsProcessed,
      totalItems: itemsProcessed,
      progressPercentage: 100.0,
      conflictsResolved: conflictsResolved,
      errorMessages: errorMessages,
      isComplete: true,
      metadata: metadata ?? {},
    );
  }

  /// Get human-readable status description
  String get statusDescription {
    if (isComplete) {
      return 'Completed ${direction.name} sync of $itemsProcessed $entityType items';
    }

    String phaseDescription;
    switch (phase) {
      case SyncPhase.validation:
        phaseDescription = 'Validating';
        break;
      case SyncPhase.transmission:
        phaseDescription = 'Transmitting';
        break;
      case SyncPhase.processing:
        phaseDescription = 'Processing';
        break;
      case SyncPhase.complete:
        phaseDescription = 'Complete';
        break;
    }

    return '$phaseDescription $entityType (${direction.name}) - Page ${currentPage + 1}/$totalPages';
  }

  /// Get unique key for this entity/device combination
  String get key => '${entityType}_$deviceId';

  @override
  String toString() {
    return 'BidirectionalSyncProgress(entityType: $entityType, deviceId: $deviceId, '
        'direction: ${direction.name}, phase: ${phase.name}, '
        'progress: ${progressPercentage.toStringAsFixed(1)}%, '
        'items: $itemsProcessed/$totalItems, conflicts: $conflictsResolved)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BidirectionalSyncProgress &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          deviceId == other.deviceId &&
          direction == other.direction &&
          phase == other.phase &&
          currentPage == other.currentPage &&
          totalPages == other.totalPages &&
          itemsProcessed == other.itemsProcessed &&
          totalItems == other.totalItems &&
          progressPercentage == other.progressPercentage &&
          conflictsResolved == other.conflictsResolved &&
          isComplete == other.isComplete;

  @override
  int get hashCode =>
      entityType.hashCode ^
      deviceId.hashCode ^
      direction.hashCode ^
      phase.hashCode ^
      currentPage.hashCode ^
      totalPages.hashCode ^
      itemsProcessed.hashCode ^
      totalItems.hashCode ^
      progressPercentage.hashCode ^
      conflictsResolved.hashCode ^
      isComplete.hashCode;
}

/// Enum for sync direction
enum SyncDirection {
  outgoing,
  incoming,
  complete,
}

/// Enum for sync phase
enum SyncPhase {
  validation,
  transmission,
  processing,
  complete,
}

/// Overall sync progress aggregator
@jsonSerializable
class OverallSyncProgress {
  /// Progress for each entity type across all devices
  final Map<String, List<BidirectionalSyncProgress>> entityProgress;

  /// Total devices being synced
  final int totalDevices;

  /// Devices that have completed sync
  final int completedDevices;

  /// Total entities being synced
  final int totalEntities;

  /// Entities that have completed sync across all devices
  final int completedEntities;

  /// Overall progress percentage (0-100)
  final double overallProgress;

  /// Total items processed across all entities/devices
  final int totalItemsProcessed;

  /// Total conflicts resolved across all entities/devices
  final int totalConflictsResolved;

  /// Any error messages from sync operations
  final List<String> errorMessages;

  /// Whether the entire sync operation is complete
  final bool isComplete;

  /// Start time of sync operation
  final DateTime startTime;

  /// End time of sync operation (if complete)
  final DateTime? endTime;

  OverallSyncProgress({
    this.entityProgress = const {},
    this.totalDevices = 0,
    this.completedDevices = 0,
    this.totalEntities = 0,
    this.completedEntities = 0,
    this.overallProgress = 0.0,
    this.totalItemsProcessed = 0,
    this.totalConflictsResolved = 0,
    this.errorMessages = const [],
    this.isComplete = false,
    DateTime? startTime,
    this.endTime,
  }) : startTime = startTime ?? DateTime.now();

  /// Duration of sync operation
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get progress for a specific entity type
  List<BidirectionalSyncProgress> getEntityProgress(String entityType) {
    return entityProgress[entityType] ?? [];
  }

  /// Get all active (incomplete) sync operations
  List<BidirectionalSyncProgress> get activeOperations {
    final active = <BidirectionalSyncProgress>[];
    for (final progressList in entityProgress.values) {
      active.addAll(progressList.where((p) => !p.isComplete));
    }
    return active;
  }

  /// Get all completed sync operations
  List<BidirectionalSyncProgress> get completedOperations {
    final completed = <BidirectionalSyncProgress>[];
    for (final progressList in entityProgress.values) {
      completed.addAll(progressList.where((p) => p.isComplete));
    }
    return completed;
  }

  @override
  String toString() {
    return 'OverallSyncProgress(devices: $completedDevices/$totalDevices, '
        'entities: $completedEntities/$totalEntities, '
        'progress: ${overallProgress.toStringAsFixed(1)}%, '
        'duration: ${duration.inSeconds}s)';
  }
}
