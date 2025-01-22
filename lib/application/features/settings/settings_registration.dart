import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/commands/delete_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/application/features/settings/queries/get_list_settings_query.dart';

void registerSettingsFeature(
  IContainer container,
  Mediator mediator,
  ISettingRepository settingRepository,
) {
  mediator
    ..registerHandler<SaveSettingCommand, SaveSettingCommandResponse, SaveSettingCommandHandler>(
      () => SaveSettingCommandHandler(settingRepository: settingRepository),
    )
    ..registerHandler<DeleteSettingCommand, DeleteSettingCommandResponse, DeleteSettingCommandHandler>(
      () => DeleteSettingCommandHandler(settingRepository: settingRepository),
    )
    ..registerHandler<GetSettingQuery, GetSettingQueryResponse, GetSettingQueryHandler>(
      () => GetSettingQueryHandler(settingRepository: settingRepository),
    )
    ..registerHandler<GetListSettingsQuery, GetListSettingsQueryResponse, GetListSettingsQueryHandler>(
      () => GetListSettingsQueryHandler(settingRepository: settingRepository),
    );
}
