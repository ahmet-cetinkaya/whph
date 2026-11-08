import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';

/// The devices of the sync group with their last sync outcome (FR-016,
/// FR-017), then the devices paired with the old sync that must pair again
/// (FR-061).
class GetListSyncMembersQuery implements IRequest<GetListSyncMembersQueryResponse> {}

class GetListSyncMembersQueryResponse {
  final List<SyncMemberSummary> members;

  const GetListSyncMembersQueryResponse(this.members);
}

/// Builds the summaries both member queries return.
class SyncMemberSummaryReader {
  final SyncMembershipService _membershipService;
  final ISyncPeerStatusStore _statusStore;
  final ISyncDeviceRepository _legacyDeviceRepository;
  final bool Function(String memberId) _itemsCannotBeApplied;

  SyncMemberSummaryReader({
    required SyncMembershipService membershipService,
    required ISyncPeerStatusStore statusStore,
    required ISyncDeviceRepository legacyDeviceRepository,
    required bool Function(String memberId) itemsCannotBeApplied,
  })  : _membershipService = membershipService,
        _statusStore = statusStore,
        _legacyDeviceRepository = legacyDeviceRepository,
        _itemsCannotBeApplied = itemsCannotBeApplied;

  Future<List<SyncMemberSummary>> readAll() async => [...await _readPeers(), ...await _readLegacyDevices()];

  Future<List<SyncMemberSummary>> _readPeers() async {
    if (!_membershipService.hasIdentity) return const [];
    final view = await _membershipService.currentView();
    final statuses = {for (final status in await _statusStore.readAll()) status.memberId: status};
    final labels = await _statusStore.readMemberLabels();
    return [
      for (final member in view.activeMembers)
        if (member.memberId != view.memberId)
          SyncMemberSummary(
            memberId: member.memberId,
            name: labels[member.memberId]?.name ?? member.name,
            platform: labels[member.memberId]?.platform,
            lastSuccessfulSync: statuses[member.memberId]?.lastSuccessLocal,
            lastResult: _resultOf(member.memberId, statuses[member.memberId], view),
            itemsCannotBeApplied: _itemsCannotBeApplied(member.memberId),
          ),
    ];
  }

  SyncResultCategory? _resultOf(String memberId, SyncPeerStatus? status, MembershipView view) =>
      view.peersNeedingRepairing.contains(memberId) ? SyncResultCategory.needsRepairing : status?.lastResult;

  /// Every row of the old device table: the new sync never writes it, and the
  /// v38 migration marked each existing row as needing repair.
  Future<List<SyncMemberSummary>> _readLegacyDevices() async {
    final devices = await _legacyDeviceRepository.getAll();
    return [
      for (final device in devices)
        SyncMemberSummary(
          memberId: device.id,
          name: device.name ?? '',
          lastSuccessfulSync: device.lastSyncDate,
          lastResult: SyncResultCategory.needsRepairing,
          isLegacy: true,
        ),
    ];
  }
}

class GetListSyncMembersQueryHandler
    implements IRequestHandler<GetListSyncMembersQuery, GetListSyncMembersQueryResponse> {
  final SyncMemberSummaryReader _reader;

  GetListSyncMembersQueryHandler(this._reader);

  @override
  Future<GetListSyncMembersQueryResponse> call(GetListSyncMembersQuery request) async =>
      GetListSyncMembersQueryResponse(await _reader.readAll());
}
