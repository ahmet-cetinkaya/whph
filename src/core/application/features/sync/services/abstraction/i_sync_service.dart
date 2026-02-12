import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:application/features/sync/models/sync_status.dart';
import 'package:application/shared/services/abstraction/i_transaction_service.dart';

abstract class ISyncService {
  void startSync();
  void stopSync();
  void dispose();
  Future<void> runSync({bool isManual = false});
  Future<void> runPaginatedSync({bool isManual = false});
  Stream<bool> get onSyncComplete;
  Stream<SyncProgress> get progressStream;

  // Sync status tracking
  Stream<SyncStatus> get syncStatusStream;
  SyncStatus get currentSyncStatus;
  void updateSyncStatus(SyncStatus status);

  // Transaction service for database operations
  ITransactionService? get transactionService;
}
