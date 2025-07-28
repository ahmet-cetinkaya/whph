import 'package:whph/src/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/src/core/application/features/sync/models/sync_status.dart';

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
}
