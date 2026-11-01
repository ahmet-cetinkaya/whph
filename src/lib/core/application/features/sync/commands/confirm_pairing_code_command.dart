import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// The user saw the same code on both screens. Responds with the next state
/// that needs the user, or the end of the pairing.
class ConfirmPairingCodeCommand implements IRequest<SyncPairingStatus> {}

class ConfirmPairingCodeCommandHandler implements IRequestHandler<ConfirmPairingCodeCommand, SyncPairingStatus> {
  final SyncPairingService _pairingService;

  ConfirmPairingCodeCommandHandler(this._pairingService);

  @override
  Future<SyncPairingStatus> call(ConfirmPairingCodeCommand request) => _pairingService.confirmCode();
}
