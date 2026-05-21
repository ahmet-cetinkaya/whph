import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';

abstract class BaseNotificationService implements INotificationService {
  final Mediator mediator;

  /// The component name to use for logging
  String get componentName;

  BaseNotificationService(this.mediator);

  @override
  Future<void> destroy() async {
    await clearAll();
  }

  @override
  Future<bool> isEnabled() async {
    final query = GetSettingQuery(key: SettingKeys.notifications);
    final setting = await mediator.send<GetSettingQuery, GetSettingQueryResponse?>(query);

    if (setting == null) {
      Logger.warning(
        '$componentName: Notification setting not found, defaulting to enabled',
        component: componentName,
      );
      return true; // Default to true if no setting
    }

    final isEnabled = setting.value == 'false' ? false : true;
    return isEnabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final command = SaveSettingCommand(
      key: SettingKeys.notifications,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    );

    await mediator.send(command);
  }
}
