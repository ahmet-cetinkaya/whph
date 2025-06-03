import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';

abstract class ISettingRepository extends IRepository<Setting, String> {
  Future<Setting?> getByKey(String key);
}
