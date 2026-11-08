import 'package:whph/core/application/features/sync/models/sync_result_category.dart';

/// What this device knows about one peer between sessions (D13, FR-016).
class SyncPeerStatus {
  final String memberId;
  final List<String> addresses;

  /// Local time of the last fully successful session.
  final DateTime? lastSuccessLocal;
  final SyncResultCategory? lastResult;

  const SyncPeerStatus({
    required this.memberId,
    this.addresses = const [],
    this.lastSuccessLocal,
    this.lastResult,
  });
}

/// What the member table shows for a member.
class SyncMemberLabel {
  final String? name;
  final String? platform;

  const SyncMemberLabel({this.name, this.platform});
}

/// Local-only per-peer session outcome and address list over
/// `sync_peer_state_table`.
abstract interface class ISyncPeerStatusStore {
  Future<List<SyncPeerStatus>> readAll();

  Future<SyncPeerStatus?> read(String memberId);

  /// A fully successful session ended at [at]; the category is not touched.
  Future<void> recordSuccess(String memberId, DateTime at);

  /// Sets the category without touching the last successful time (`null`
  /// clears it).
  Future<void> setResult(String memberId, SyncResultCategory? category);

  Future<void> saveAddresses(String memberId, List<String> addresses);

  /// The stored name and platform of each member that has a row.
  Future<Map<String, SyncMemberLabel>> readMemberLabels();

  /// Stores the platform of a member whose row exists; a no-op otherwise.
  Future<void> savePlatform(String memberId, String platform);
}
