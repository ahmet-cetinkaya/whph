abstract class ISyncService {
  void startSync();
  void stopSync();
  void dispose();
  Future<void> runSync();
  Stream<bool> get onSyncComplete;
}
