import 'package:acore/acore.dart' hide IRepository;
import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';

/// Configuration for a specific entity type in paginated sync operations
class PaginatedSyncConfig<T extends BaseEntity<String>> {
  final String name;
  final IRepository<T, String> repository;
  final Future<PaginatedSyncData<T>> Function(DateTime, int, int, String?) getPaginatedSyncData;
  final PaginatedSyncData<T>? Function(PaginatedSyncDataDto) getPaginatedSyncDataFromDto;

  PaginatedSyncConfig({
    required this.name,
    required this.repository,
    required this.getPaginatedSyncData,
    required this.getPaginatedSyncDataFromDto,
  });
}

/// Service responsible for managing sync entity configurations
abstract class ISyncConfigurationService {
  /// Gets all registered sync configurations
  List<PaginatedSyncConfig> getAllConfigurations();

  /// Gets a specific configuration by entity type name
  PaginatedSyncConfig? getConfiguration(String entityType);

  /// Gets a strongly-typed configuration for a specific entity type
  PaginatedSyncConfig<T>? getTypedConfiguration<T extends BaseEntity<String>>(String entityType);

  /// Registers a new sync configuration
  void registerConfiguration<T extends BaseEntity<String>>(PaginatedSyncConfig<T> config);

  /// Gets the names of all registered entity types
  List<String> getEntityTypeNames();

  /// Checks if a specific entity type is registered
  bool hasEntityType(String entityType);
}
