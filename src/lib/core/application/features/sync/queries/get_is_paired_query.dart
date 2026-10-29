import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';

/// Whether this device is paired (U6): it holds group keys, is neither removed
/// from the group nor key-lost, and has a non-revoked member besides itself.
/// The import, reset and demo texts and the demo gate use it.
class GetIsPairedQuery implements IRequest<GetIsPairedQueryResponse> {}

class GetIsPairedQueryResponse {
  final bool isPaired;

  /// Distinguishes a device removed from its group (the UI says so) from one
  /// that never paired.
  final SyncGroupState groupState;

  const GetIsPairedQueryResponse({required this.isPaired, this.groupState = SyncGroupState.ungrouped});
}

class GetIsPairedQueryHandler
    implements IRequestHandler<GetIsPairedQuery, GetIsPairedQueryResponse> {
  final SyncMembershipService _membershipService;

  GetIsPairedQueryHandler(this._membershipService);

  @override
  Future<GetIsPairedQueryResponse> call(GetIsPairedQuery request) async {
    if (!_membershipService.hasIdentity) return const GetIsPairedQueryResponse(isPaired: false);
    final view = await _membershipService.currentView();
    return GetIsPairedQueryResponse(isPaired: view.isPaired, groupState: view.state);
  }
}
