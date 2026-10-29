import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// Pairs with the device that shows the scanned QR code [qrText].
class PairFromInvitationCommand implements IRequest<SyncPairingStatus> {
  final String qrText;

  PairFromInvitationCommand({required this.qrText});
}

class PairFromInvitationCommandHandler implements IRequestHandler<PairFromInvitationCommand, SyncPairingStatus> {
  final SyncPairingService _pairingService;

  PairFromInvitationCommandHandler(this._pairingService);

  @override
  Future<SyncPairingStatus> call(PairFromInvitationCommand request) async {
    final PairingInvitation invitation;
    try {
      invitation = PairingInvitation.decode(request.qrText);
    } on Object {
      return const SyncPairingStatus(
        phase: SyncPairingPhase.failed,
        role: SyncPairingRole.joiner,
        errorCode: SyncPairingErrorCode.invalidInvitation,
      );
    }
    return _pairingService.pairFromInvitation(invitation);
  }
}
