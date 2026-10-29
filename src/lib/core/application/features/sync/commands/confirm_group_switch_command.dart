import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// The user agrees to leave the current group and join the other device's
/// group (NB-1).
class ConfirmGroupSwitchCommand implements IRequest<SyncPairingStatus> {}

class ConfirmGroupSwitchCommandHandler implements IRequestHandler<ConfirmGroupSwitchCommand, SyncPairingStatus> {
  final SyncPairingService _pairingService;

  ConfirmGroupSwitchCommandHandler(this._pairingService);

  @override
  Future<SyncPairingStatus> call(ConfirmGroupSwitchCommand request) => _pairingService.confirmGroupSwitch();
}
