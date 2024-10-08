import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';

class SaveSettingCommand implements IRequest<SaveSettingCommandResponse> {
  final int? id;
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
  final int id;
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
        throw Exception('Setting with id ${request.id} not found');
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
      id: 0,
      createdDate: DateTime(0),
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