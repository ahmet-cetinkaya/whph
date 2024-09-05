import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';

class DeleteSettingCommand implements IRequest<DeleteSettingCommandResponse> {
  final int id;

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
      throw Exception('Setting with id ${request.id} not found');
    }

    await _settingRepository.delete(setting.id);

    return DeleteSettingCommandResponse();
  }
}
