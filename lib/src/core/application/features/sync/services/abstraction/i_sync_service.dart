import 'package:whph/src/core/application/features/sync/models/paginated_sync_data.dart';

abstract class ISyncService {
  void startSync();
  void stopSync();
  void dispose();
  Future<void> runSync();
  Future<void> runPaginatedSync();
  Stream<bool> get onSyncComplete;
  Stream<SyncProgress> get progressStream;
}
