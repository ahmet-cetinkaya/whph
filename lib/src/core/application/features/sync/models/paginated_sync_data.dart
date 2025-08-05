import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'sync_data.dart';

/// Represents a paginated chunk of sync data for efficient memory usage and network transmission
@jsonSerializable
class PaginatedSyncData<T extends BaseEntity> {
  /// The actual sync data for this page
  final SyncData<T> data;

  /// Current page number (0-based)
  final int pageIndex;

  /// Number of items per page
  final int pageSize;

  /// Total number of pages available
  final int totalPages;

  /// Total number of items across all pages
  final int totalItems;

  /// Whether this is the last page
  final bool isLastPage;

  /// Entity type identifier for deserialization
  final String entityType;

  PaginatedSyncData({
    required this.data,
    required this.pageIndex,
    required this.pageSize,
    required this.totalPages,
    required this.totalItems,
    required this.isLastPage,
    required this.entityType,
  });

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
        'pageIndex': pageIndex,
        'pageSize': pageSize,
        'totalPages': totalPages,
        'totalItems': totalItems,
        'isLastPage': isLastPage,
        'entityType': entityType,
      };

  factory PaginatedSyncData.fromJson(Map<String, dynamic> json, Type type) {
    return PaginatedSyncData(
      data: SyncData<T>.fromJson(json['data'] as Map<String, dynamic>, type),
      pageIndex: json['pageIndex'] as int,
      pageSize: json['pageSize'] as int,
      totalPages: json['totalPages'] as int,
      totalItems: json['totalItems'] as int,
      isLastPage: json['isLastPage'] as bool,
      entityType: json['entityType'] as String,
    );
  }
}

/// Configuration for pagination settings
class SyncPaginationConfig {
  /// Default page size for database operations
  static const int defaultDatabasePageSize = 200;

  /// Default page size for network transmission
  static const int defaultNetworkPageSize = 50;

  /// Maximum page size to prevent memory issues
  static const int maxPageSize = 500;

  /// Delay between batch operations to prevent overwhelming the system
  static const Duration batchDelay = Duration(milliseconds: 50);

  /// Timeout for individual batch operations
  static const Duration batchTimeout = Duration(seconds: 30);
}

/// Progress information for sync operations
@jsonSerializable
class SyncProgress {
  /// Current entity being processed
  final String currentEntity;

  /// Current page being processed
  final int currentPage;

  /// Total pages for current entity
  final int totalPages;

  /// Overall progress percentage (0-100)
  final double progressPercentage;

  /// Number of entities completed
  final int entitiesCompleted;

  /// Total number of entities to process
  final int totalEntities;

  /// Current operation (e.g., "fetching", "transmitting", "processing")
  final String operation;

  SyncProgress({
    required this.currentEntity,
    required this.currentPage,
    required this.totalPages,
    required this.progressPercentage,
    required this.entitiesCompleted,
    required this.totalEntities,
    required this.operation,
  });

  Map<String, dynamic> toJson() => {
        'currentEntity': currentEntity,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'progressPercentage': progressPercentage,
        'entitiesCompleted': entitiesCompleted,
        'totalEntities': totalEntities,
        'operation': operation,
      };

  factory SyncProgress.fromJson(Map<String, dynamic> json) {
    return SyncProgress(
      currentEntity: json['currentEntity'] as String,
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
      progressPercentage: (json['progressPercentage'] as num).toDouble(),
      entitiesCompleted: json['entitiesCompleted'] as int,
      totalEntities: json['totalEntities'] as int,
      operation: json['operation'] as String,
    );
  }
}
