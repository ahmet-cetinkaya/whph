import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

const _needsRepairingCategory = 'needs_repairing';
const _addressSeparator = '\n';

/// [ISyncPeerStateStore] over the local-only `sync_peer_state_table` (D13).
/// "Needs re-pairing" is the row's `last_result_category`; the addresses are
/// stored newline-separated.
class DriftSyncPeerStateStore implements ISyncPeerStateStore {
  final AppDatabase _database;

  DriftSyncPeerStateStore(this._database);

  @override
  Future<Set<String>> peersNeedingRepairing() async {
    final rows = await _database.customSelect(
      'SELECT member_id FROM sync_peer_state_table WHERE last_result_category = ?',
      variables: [Variable<String>(_needsRepairingCategory)],
    ).get();
    return {for (final row in rows) row.read<String>('member_id')};
  }

  @override
  Future<void> markNeedsRepairing(String memberId) => _database.customStatement(
        "INSERT INTO sync_peer_state_table (member_id, addresses, last_result_category) VALUES (?, '', ?) "
        'ON CONFLICT (member_id) DO UPDATE SET last_result_category = excluded.last_result_category',
        [memberId, _needsRepairingCategory],
      );

  @override
  Future<void> clearNeedsRepairing(String memberId) =>
      _database.customStatement(
        'UPDATE sync_peer_state_table SET last_result_category = NULL WHERE member_id = ? AND last_result_category = ?',
        [memberId, _needsRepairingCategory],
      );

  @override
  Future<List<String>> addressesOf(String memberId) async {
    final rows = await _database.customSelect(
      'SELECT addresses FROM sync_peer_state_table WHERE member_id = ?',
      variables: [Variable<String>(memberId)],
    ).get();
    if (rows.isEmpty) return const [];
    return _split(rows.single.read<String>('addresses'));
  }

  @override
  Future<void> moveAddress(String address,
      {required String fromMemberId, required String toMemberId}) async {
    await saveAddresses(fromMemberId,
        (await addressesOf(fromMemberId)).where((a) => a != address).toList());
    final target = await addressesOf(toMemberId);
    if (!target.contains(address))
      await saveAddresses(toMemberId, [...target, address]);
  }

  /// Replaces the stored address list of [memberId].
  Future<void> saveAddresses(String memberId, List<String> addresses) =>
      _database.customStatement(
        'INSERT INTO sync_peer_state_table (member_id, addresses) VALUES (?, ?) '
        'ON CONFLICT (member_id) DO UPDATE SET addresses = excluded.addresses',
        [memberId, addresses.join(_addressSeparator)],
      );

  List<String> _split(String stored) =>
      stored.isEmpty ? const [] : stored.split(_addressSeparator);
}
