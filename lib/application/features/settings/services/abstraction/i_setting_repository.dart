import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';

abstract class ISettingRepository extends IRepository<Setting, String> {
  Future<Setting?> getByKey(String key);
}
