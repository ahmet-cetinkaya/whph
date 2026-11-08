import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// Shows a pairing invitation (QR code, 5 minutes, one successful use).
class CreatePairingInvitationCommand implements IRequest<CreatePairingInvitationCommandResponse> {}

class CreatePairingInvitationCommandResponse {
  final PairingInvitation invitation;

  /// The text to render as a QR code.
  final String qrText;

  const CreatePairingInvitationCommandResponse({required this.invitation, required this.qrText});
}

class CreatePairingInvitationCommandHandler
    implements IRequestHandler<CreatePairingInvitationCommand, CreatePairingInvitationCommandResponse> {
  final SyncPairingService _pairingService;

  CreatePairingInvitationCommandHandler(this._pairingService);

  @override
  Future<CreatePairingInvitationCommandResponse> call(CreatePairingInvitationCommand request) async {
    final invitation = await _pairingService.createInvitation();
    return CreatePairingInvitationCommandResponse(invitation: invitation, qrText: invitation.encode());
  }
}
