import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_state_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

/// [ISyncPeerStatusStore] over the local-only `sync_peer_state_table` (D13)
/// and the platform column of `sync_member_table`.
class DriftSyncPeerStatusStore implements ISyncPeerStatusStore {
  final AppDatabase _database;
  final DriftSyncPeerStateStore _addresses;

  DriftSyncPeerStatusStore(this._database) : _addresses = DriftSyncPeerStateStore(_database);

  @override
  Future<List<SyncPeerStatus>> readAll() async {
    final rows = await _database
        .customSelect(
          'SELECT member_id, last_success_local, last_result_category FROM sync_peer_state_table',
        )
        .get();
    return [for (final row in rows) await _toStatus(row)];
  }

  @override
  Future<SyncPeerStatus?> read(String memberId) async {
    final rows = await _database.customSelect(
      'SELECT member_id, last_success_local, last_result_category FROM sync_peer_state_table WHERE member_id = ?',
      variables: [Variable<String>(memberId)],
    ).get();
    return rows.isEmpty ? null : _toStatus(rows.single);
  }

  Future<SyncPeerStatus> _toStatus(QueryRow row) async {
    final memberId = row.read<String>('member_id');
    return SyncPeerStatus(
      memberId: memberId,
      addresses: await _addresses.addressesOf(memberId),
      lastSuccessLocal: row.readNullable<DateTime>('last_success_local'),
      lastResult: SyncResultCategory.fromCode(row.readNullable<String>('last_result_category')),
    );
  }

  @override
  Future<void> recordSuccess(String memberId, DateTime at) => _database.customUpdate(
        "INSERT INTO sync_peer_state_table (member_id, addresses, last_success_local) VALUES (?, '', ?) "
        'ON CONFLICT (member_id) DO UPDATE SET last_success_local = excluded.last_success_local',
        variables: [Variable<String>(memberId), Variable<DateTime>(at)],
      );

  @override
  Future<void> setResult(String memberId, SyncResultCategory? category) => _database.customUpdate(
        "INSERT INTO sync_peer_state_table (member_id, addresses, last_result_category) VALUES (?, '', ?) "
        'ON CONFLICT (member_id) DO UPDATE SET last_result_category = excluded.last_result_category',
        variables: [Variable<String>(memberId), Variable<String>(category?.code)],
      );

  @override
  Future<void> saveAddresses(String memberId, List<String> addresses) => _addresses.saveAddresses(memberId, addresses);

  @override
  Future<Map<String, SyncMemberLabel>> readMemberLabels() async {
    final rows = await _database
        .customSelect(
          'SELECT member_id, name, platform FROM sync_member_table WHERE deleted_date IS NULL',
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('member_id'): SyncMemberLabel(
          name: row.readNullable<String>('name'),
          platform: row.readNullable<String>('platform'),
        ),
    };
  }

  @override
  Future<void> savePlatform(String memberId, String platform) => _database.customUpdate(
        'UPDATE sync_member_table SET platform = ? WHERE member_id = ?',
        variables: [Variable<String>(platform), Variable<String>(memberId)],
      );
}
