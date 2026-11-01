import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';

/// Changes the name the group shows for a device.
class RenameSyncMemberCommand implements IRequest<void> {
  final String memberId;
  final String name;

  RenameSyncMemberCommand({required this.memberId, required this.name});
}

class RenameSyncMemberCommandHandler implements IRequestHandler<RenameSyncMemberCommand, void> {
  final SyncMembershipService _membershipService;

  RenameSyncMemberCommandHandler(this._membershipService);

  @override
  Future<void> call(RenameSyncMemberCommand request) => _membershipService.renameMember(request.memberId, request.name);
}
