import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph/src/core/domain/features/sync/sync_device.dart';

abstract class ISyncDeviceRepository extends app.IRepository<SyncDevice, String> {
  Future<SyncDevice?> getByFromToIp(String fromIp, String toIp);
}
