import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// Ends the pairing in progress and stops showing the invitation.
class CancelPairingCommand implements IRequest<void> {}

class CancelPairingCommandHandler implements IRequestHandler<CancelPairingCommand, void> {
  final SyncPairingService _pairingService;

  CancelPairingCommandHandler(this._pairingService);

  @override
  Future<void> call(CancelPairingCommand request) async => _pairingService.cancel();
}
