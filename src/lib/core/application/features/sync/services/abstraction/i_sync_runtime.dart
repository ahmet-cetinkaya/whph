/// The running part of sync: the LAN server for incoming sessions and the
/// periodic run of outgoing ones.
abstract interface class ISyncRuntime {
  Future<void> start();

  Future<void> stop();
}
