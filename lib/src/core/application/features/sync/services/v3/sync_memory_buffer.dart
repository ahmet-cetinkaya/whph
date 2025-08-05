import 'dart:collection';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Memory buffer for sync data - holds all data in RAM before database writes
class SyncMemoryBuffer {
  final String sessionId;
  final Map<String, SyncEntityBuffer> _entityBuffers = {};
  final DateTime _createdAt = DateTime.now();
  
  SyncMemoryBuffer(this.sessionId);

  /// Add entity buffer for specific type
  void addEntityBuffer(String entityType) {
    if (_entityBuffers.containsKey(entityType)) {
      Logger.warning('🧠 SyncMemoryBuffer: Entity buffer for $entityType already exists, clearing...');
      _entityBuffers[entityType]?.clear();
    }
    
    _entityBuffers[entityType] = SyncEntityBuffer(entityType);
    Logger.debug('🧠 SyncMemoryBuffer: Created entity buffer for $entityType');
  }

  /// Get entity buffer
  SyncEntityBuffer? getEntityBuffer(String entityType) {
    return _entityBuffers[entityType];
  }

  /// Add data to entity buffer
  void addData(String entityType, String operation, Map<String, dynamic> data) {
    final buffer = _entityBuffers[entityType];
    if (buffer == null) {
      Logger.error('🧠 SyncMemoryBuffer: No buffer found for entity type $entityType');
      return;
    }

    buffer.addData(operation, data);
    Logger.debug('🧠 SyncMemoryBuffer: Added $operation data for $entityType (id: ${data['id']})');
  }

  /// Add batch data to entity buffer
  void addBatchData(String entityType, String operation, List<Map<String, dynamic>> dataList) {
    final buffer = _entityBuffers[entityType];
    if (buffer == null) {
      Logger.error('🧠 SyncMemoryBuffer: No buffer found for entity type $entityType');
      return;
    }

    for (final data in dataList) {
      buffer.addData(operation, data);
    }
    
    Logger.debug('🧠 SyncMemoryBuffer: Added ${dataList.length} $operation items for $entityType');
  }

  /// Get all entity types in buffer
  List<String> get entityTypes => _entityBuffers.keys.toList();

  /// Get total item count across all entities
  int get totalItemCount {
    return _entityBuffers.values.fold(0, (sum, buffer) => sum + buffer.totalItemCount);
  }

  /// Get memory usage estimate in bytes
  int get estimatedMemoryUsage {
    int totalSize = 0;
    for (final buffer in _entityBuffers.values) {
      totalSize += buffer.estimatedMemoryUsage;
    }
    return totalSize;
  }

  /// Check if buffer is empty
  bool get isEmpty => _entityBuffers.isEmpty || _entityBuffers.values.every((buffer) => buffer.isEmpty);

  /// Clear all buffers
  void clear() {
    for (final buffer in _entityBuffers.values) {
      buffer.clear();
    }
    _entityBuffers.clear();
    Logger.info('🧠 SyncMemoryBuffer: Cleared all buffers for session $sessionId');
  }

  /// Get buffer summary
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('🧠 SyncMemoryBuffer Summary (Session: $sessionId):');
    buffer.writeln('  Created: ${_createdAt.toIso8601String()}');
    buffer.writeln('  Age: ${DateTime.now().difference(_createdAt).inSeconds}s');
    buffer.writeln('  Total items: $totalItemCount');
    buffer.writeln('  Memory usage: ${(estimatedMemoryUsage / 1024).toStringAsFixed(2)} KB');
    buffer.writeln('  Entity buffers: ${_entityBuffers.length}');
    
    for (final entityType in entityTypes) {
      final entityBuffer = _entityBuffers[entityType]!;
      buffer.writeln('    - $entityType: ${entityBuffer.totalItemCount} items (${entityBuffer.operationSummary})');
    }
    
    return buffer.toString();
  }

  @override
  String toString() => 'SyncMemoryBuffer(session: $sessionId, entities: ${entityTypes.length}, items: $totalItemCount)';
}

/// Buffer for a specific entity type
class SyncEntityBuffer {
  final String entityType;
  final Map<String, Queue<Map<String, dynamic>>> _operationBuffers = {
    'create': Queue<Map<String, dynamic>>(),
    'update': Queue<Map<String, dynamic>>(),
    'delete': Queue<Map<String, dynamic>>(),
  };

  SyncEntityBuffer(this.entityType);

  /// Add data for specific operation
  void addData(String operation, Map<String, dynamic> data) {
    if (!_operationBuffers.containsKey(operation)) {
      Logger.error('🧠 SyncEntityBuffer: Unknown operation $operation for $entityType');
      return;
    }

    _operationBuffers[operation]!.add(Map<String, dynamic>.from(data));
  }

  /// Get data for specific operation
  List<Map<String, dynamic>> getData(String operation) {
    return _operationBuffers[operation]?.toList() ?? [];
  }

  /// Get all create operations
  List<Map<String, dynamic>> get createData => getData('create');

  /// Get all update operations  
  List<Map<String, dynamic>> get updateData => getData('update');

  /// Get all delete operations
  List<Map<String, dynamic>> get deleteData => getData('delete');

  /// Get total item count
  int get totalItemCount {
    return _operationBuffers.values.fold(0, (sum, queue) => sum + queue.length);
  }

  /// Get count for specific operation
  int getOperationCount(String operation) {
    return _operationBuffers[operation]?.length ?? 0;
  }

  /// Check if buffer is empty
  bool get isEmpty => totalItemCount == 0;

  /// Clear all operation buffers
  void clear() {
    for (final queue in _operationBuffers.values) {
      queue.clear();
    }
    Logger.debug('🧠 SyncEntityBuffer: Cleared buffer for $entityType');
  }

  /// Get estimated memory usage in bytes
  int get estimatedMemoryUsage {
    int totalSize = 0;
    for (final queue in _operationBuffers.values) {
      for (final item in queue) {
        // Rough estimate: JSON string length * 2 (for UTF-16)
        totalSize += item.toString().length * 2;
      }
    }
    return totalSize;
  }

  /// Get operation summary string
  String get operationSummary {
    return 'C:${getOperationCount('create')}, U:${getOperationCount('update')}, D:${getOperationCount('delete')}';
  }

  @override
  String toString() => 'SyncEntityBuffer($entityType: $operationSummary)';
}