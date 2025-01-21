import 'package:whph/application/shared/services/i_repository.dart';
import 'package:whph/domain/features/sync/sync_device.dart';

abstract class ISyncDeviceRepository extends IRepository<SyncDevice, String> {
  Future<SyncDevice?> getByFromToIp(String fromIp, String toIp);
}
