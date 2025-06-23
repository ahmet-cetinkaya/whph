import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/application/features/settings/constants/setting_translation_keys.dart';

class DeleteSettingCommand implements IRequest<DeleteSettingCommandResponse> {
  final String id;

  DeleteSettingCommand({required this.id});
}

class DeleteSettingCommandResponse {}

class DeleteSettingCommandHandler implements IRequestHandler<DeleteSettingCommand, DeleteSettingCommandResponse> {
  final ISettingRepository _settingRepository;

  DeleteSettingCommandHandler({required ISettingRepository settingRepository}) : _settingRepository = settingRepository;

  @override
  Future<DeleteSettingCommandResponse> call(DeleteSettingCommand request) async {
    Setting? setting = await _settingRepository.getById(request.id);
    if (setting == null) {
      throw BusinessException('Setting not found', SettingTranslationKeys.settingNotFoundError);
    }

    await _settingRepository.delete(setting);

    return DeleteSettingCommandResponse();
  }
}
