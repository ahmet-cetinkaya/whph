import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';

/// Gives a device that was removed from its group a new identity so it can
/// pair again; its data stays.
class RenewSyncIdentityCommand implements IRequest<void> {}

class RenewSyncIdentityCommandHandler implements IRequestHandler<RenewSyncIdentityCommand, void> {
  final SyncMembershipService _membershipService;

  RenewSyncIdentityCommandHandler(this._membershipService);

  @override
  Future<void> call(RenewSyncIdentityCommand request) => _membershipService.renewIdentity();
}
