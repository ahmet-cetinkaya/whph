import 'package:whph/core/application/features/settings/models/public_setting.dart';

abstract interface class ISettingsEffects {
  Future<void> apply(PublicSettingChange change);
}
