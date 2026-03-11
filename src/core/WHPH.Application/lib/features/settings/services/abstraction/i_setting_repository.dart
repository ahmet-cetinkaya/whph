import 'package:whph_application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph_domain/features/settings/setting.dart';

abstract class ISettingRepository extends app.IRepository<Setting, String> {
  Future<Setting?> getByKey(String key);
}
