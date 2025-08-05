import 'package:whph/src/core/application/features/sync/models/v2/sync_entity_descriptor.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Central registry for all syncable entities
class SyncEntityRegistry {
  static final SyncEntityRegistry _instance = SyncEntityRegistry._internal();
  factory SyncEntityRegistry() => _instance;
  SyncEntityRegistry._internal();

  final Map<String, SyncEntityDescriptor> _descriptors = {};

  /// Register an entity descriptor
  void register<T>(SyncEntityDescriptor<T> descriptor) {
    final entityType = descriptor.entityType;
    
    if (_descriptors.containsKey(entityType)) {
      Logger.warning('🔄 SyncEntityRegistry: Overriding existing descriptor for $entityType');
    }
    
    _descriptors[entityType] = descriptor;
    Logger.debug('🔄 SyncEntityRegistry: Registered $entityType (priority: ${descriptor.syncPriority})');
  }

  /// Get descriptor for entity type
  SyncEntityDescriptor<T>? getDescriptor<T>(String entityType) {
    final descriptor = _descriptors[entityType];
    if (descriptor == null) {
      Logger.error('🔄 SyncEntityRegistry: No descriptor found for $entityType');
      return null;
    }
    return descriptor as SyncEntityDescriptor<T>;
  }

  /// Get all registered entity types
  List<String> get entityTypes => _descriptors.keys.toList();

  /// Get all descriptors sorted by sync priority
  List<SyncEntityDescriptor> get orderedDescriptors {
    final descriptors = _descriptors.values.toList();
    descriptors.sort((a, b) => a.syncPriority.compareTo(b.syncPriority));
    return descriptors;
  }

  /// Check if entity type is registered
  bool isRegistered(String entityType) => _descriptors.containsKey(entityType);

  /// Get registration count
  int get registrationCount => _descriptors.length;

  /// Clear all registrations (for testing)
  void clear() {
    _descriptors.clear();
    Logger.debug('🔄 SyncEntityRegistry: Cleared all registrations');
  }

  /// Get registration summary
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('🔄 SyncEntityRegistry Summary:');
    buffer.writeln('  Total registered: ${_descriptors.length}');
    
    if (_descriptors.isNotEmpty) {
      buffer.writeln('  Entities:');
      for (final descriptor in orderedDescriptors) {
        buffer.writeln('    - ${descriptor.entityType} (priority: ${descriptor.syncPriority})');
      }
    }
    
    return buffer.toString();
  }
}