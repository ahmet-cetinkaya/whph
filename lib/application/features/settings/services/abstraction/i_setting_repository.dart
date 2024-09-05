import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';

abstract class ISettingRepository extends IRepository<Setting, int> {
  Future<Setting?> getByKey(String key);
}
