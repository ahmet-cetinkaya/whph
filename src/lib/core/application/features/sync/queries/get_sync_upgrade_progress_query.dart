import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';

class GetSyncUpgradeProgressQuery implements IRequest<SyncUpgradeProgress> {}

class GetSyncUpgradeProgressQueryHandler
    implements
        IRequestHandler<GetSyncUpgradeProgressQuery, SyncUpgradeProgress> {
  final ISyncUpgradeService _upgradeService;

  GetSyncUpgradeProgressQueryHandler(
      {required ISyncUpgradeService upgradeService})
      : _upgradeService = upgradeService;

  @override
  Future<SyncUpgradeProgress> call(GetSyncUpgradeProgressQuery request) =>
      _upgradeService.getProgress();
}
