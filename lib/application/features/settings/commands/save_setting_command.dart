import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/settings/constants/setting_translation_keys.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/settings/setting.dart';

class SaveSettingCommand implements IRequest<SaveSettingCommandResponse> {
  final String? id;
  final String key;
  final String value;
  final SettingValueType valueType;

  SaveSettingCommand({
    this.id,
    required this.key,
    required this.value,
    required this.valueType,
  });
}

class SaveSettingCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveSettingCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveSettingCommandHandler implements IRequestHandler<SaveSettingCommand, SaveSettingCommandResponse> {
  final ISettingRepository _settingRepository;

  SaveSettingCommandHandler({required ISettingRepository settingRepository}) : _settingRepository = settingRepository;

  @override
  Future<SaveSettingCommandResponse> call(SaveSettingCommand request) async {
    Setting? setting;

    if (request.id != null) {
      setting = await _settingRepository.getById(request.id!);
      if (setting == null) {
        throw BusinessException(SettingTranslationKeys.settingNotFoundError);
      }

      await _update(setting, request);
    } else {
      setting = await _settingRepository.getByKey(request.key);
      if (setting != null) {
        setting = await _update(setting, request);
      } else {
        setting = await _add(setting, request);
      }
    }

    return SaveSettingCommandResponse(
      id: setting.id,
      createdDate: setting.createdDate,
      modifiedDate: setting.modifiedDate,
    );
  }

  Future<Setting> _add(Setting? setting, SaveSettingCommand request) async {
    setting = Setting(
      id: nanoid(),
      createdDate: DateTime.now(),
      key: request.key,
      value: request.value,
      valueType: request.valueType,
    );
    await _settingRepository.add(setting);
    return setting;
  }

  Future<Setting> _update(Setting setting, SaveSettingCommand request) async {
    setting.key = request.key;
    setting.value = request.value;
    setting.valueType = request.valueType;
    await _settingRepository.update(setting);
    return setting;
  }
}
