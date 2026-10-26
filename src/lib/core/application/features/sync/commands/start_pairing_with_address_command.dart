import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// Starts a code-comparison pairing with the device at [address] (LAN scan or
/// manual entry). The response is the state in which both users compare the
/// code, or the failure.
class StartPairingWithAddressCommand implements IRequest<SyncPairingStatus> {
  final String address;
  final int? port;

  StartPairingWithAddressCommand({required this.address, this.port});
}

class StartPairingWithAddressCommandHandler
    implements IRequestHandler<StartPairingWithAddressCommand, SyncPairingStatus> {
  final SyncPairingService _pairingService;

  StartPairingWithAddressCommandHandler(this._pairingService);

  @override
  Future<SyncPairingStatus> call(StartPairingWithAddressCommand request) =>
      _pairingService.startPairingWithAddress(request.address, port: request.port);
}
