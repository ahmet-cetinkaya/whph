import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';

/// Removes a device from the group (FR-026): a signed revocation and a key
/// rotation. For a device paired with the old sync, [memberId] is the legacy
/// row id and the row is deleted.
class RemoveSyncMemberCommand implements IRequest<void> {
  final String memberId;

  RemoveSyncMemberCommand({required this.memberId});
}

class RemoveSyncMemberCommandHandler implements IRequestHandler<RemoveSyncMemberCommand, void> {
  final SyncMembershipService _membershipService;
  final ISyncDeviceRepository _legacyDeviceRepository;

  RemoveSyncMemberCommandHandler(this._membershipService, this._legacyDeviceRepository);

  @override
  Future<void> call(RemoveSyncMemberCommand request) async {
    final legacyDevice = await _legacyDeviceRepository.getById(request.memberId);
    if (legacyDevice != null) {
      await _legacyDeviceRepository.delete(legacyDevice);
      return;
    }
    await _membershipService.removeMember(request.memberId);
  }
}
