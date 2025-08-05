import 'package:whph/src/core/application/features/sync/registry/sync_entity_registry.dart';
import 'package:whph/src/core/application/features/sync/descriptors/task_sync_descriptor.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:acore/acore.dart';

/// Initializes sync registry with all entity descriptors
class SyncRegistryInitializer {
  static Future<void> initialize(IContainer container) async {
    Logger.info('🔄 SyncRegistryInitializer: Starting sync registry initialization...');
    
    final registry = SyncEntityRegistry();
    final stopwatch = Stopwatch()..start();

    try {
      // Register Task entity
      await _registerTaskEntity(container, registry);
      
      // TODO: Register other entities as we migrate them
      // await _registerHabitEntity(container, registry);
      // await _registerAppUsageEntity(container, registry);
      // ... etc

      stopwatch.stop();
      Logger.info('🔄 SyncRegistryInitializer: Completed initialization in ${stopwatch.elapsedMilliseconds}ms');
      Logger.info(registry.summary);

    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('🔄 SyncRegistryInitializer: Failed to initialize sync registry: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Register Task entity descriptor
  static Future<void> _registerTaskEntity(IContainer container, SyncEntityRegistry registry) async {
    Logger.debug('🔄 SyncRegistryInitializer: Registering Task entity...');
    
    try {
      final taskRepository = container.resolve<ITaskRepository>();
      final taskDescriptor = TaskSyncDescriptor(taskRepository);
      
      registry.register(taskDescriptor);
      Logger.debug('🔄 SyncRegistryInitializer: Task entity registered successfully');
      
    } catch (e) {
      Logger.error('🔄 SyncRegistryInitializer: Failed to register Task entity: $e');
      rethrow;
    }
  }

  /// TODO: Register other entities as we migrate them
  /*
  static Future<void> _registerHabitEntity(IContainer container, SyncEntityRegistry registry) async {
    Logger.debug('🔄 SyncRegistryInitializer: Registering Habit entity...');
    
    try {
      final habitRepository = container.resolve<IHabitRepository>();
      final habitDescriptor = HabitSyncDescriptor(habitRepository);
      
      registry.register(habitDescriptor);
      Logger.debug('🔄 SyncRegistryInitializer: Habit entity registered successfully');
      
    } catch (e) {
      Logger.error('🔄 SyncRegistryInitializer: Failed to register Habit entity: $e');
      rethrow;
    }
  }
  */

  /// Get initialization status
  static String getInitializationStatus() {
    final registry = SyncEntityRegistry();
    return '''
🔄 Sync Registry Status:
  Initialized: ${registry.registrationCount > 0}
  Registered entities: ${registry.registrationCount}
  Available types: ${registry.entityTypes.join(', ')}
''';
  }
}