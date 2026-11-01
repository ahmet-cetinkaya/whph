import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';

/// The state of the pairing in progress, or of the last one.
class GetSyncPairingStatusQuery implements IRequest<SyncPairingStatus> {}

class GetSyncPairingStatusQueryHandler implements IRequestHandler<GetSyncPairingStatusQuery, SyncPairingStatus> {
  final SyncPairingService _pairingService;

  GetSyncPairingStatusQueryHandler(this._pairingService);

  @override
  Future<SyncPairingStatus> call(GetSyncPairingStatusQuery request) async => _pairingService.status;
}
