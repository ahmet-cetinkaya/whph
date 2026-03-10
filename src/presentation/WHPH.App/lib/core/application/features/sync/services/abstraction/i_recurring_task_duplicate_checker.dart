import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';

/// Interface for checking and handling recurring task duplicates during sync.
abstract class IRecurringTaskDuplicateChecker {
  /// Check for recurring task duplicates (typed version)
  Future<T?> checkForDuplicate<T extends BaseEntity<String>>(
    T entity,
    IRepository<T, String> repository,
  );

  /// Check for recurring task duplicates (dynamic version)
  Future<dynamic> checkForDuplicateDynamic(
    BaseEntity<String> entity,
    IRepository repository,
  );
}
