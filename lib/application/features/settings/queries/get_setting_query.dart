import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';

class GetSettingQuery implements IRequest<GetSettingQueryResponse> {
  late String? id;
  late String? key;

  GetSettingQuery({this.id, this.key});
}

class SettingSettingListItem {
  String id;
  String key;
  String value;
  String valueType;

  SettingSettingListItem({
    required this.id,
    required this.key,
    required this.value,
    required this.valueType,
  });
}

class GetSettingQueryResponse extends Setting {
  GetSettingQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.key,
    required super.value,
    required super.valueType,
  });
}

class GetSettingQueryHandler implements IRequestHandler<GetSettingQuery, GetSettingQueryResponse> {
  late final ISettingRepository _settingRepository;

  GetSettingQueryHandler({required ISettingRepository settingRepository}) : _settingRepository = settingRepository;

  @override
  Future<GetSettingQueryResponse> call(GetSettingQuery request) async {
    Setting? settings;
    if (request.id != null) {
      settings = await _settingRepository.getById(
        request.id!,
      );
    } else if (request.key != null) {
      settings = await _settingRepository.getByKey(
        request.key!,
      );
    }
    if (settings == null) {
      throw Exception('Setting with id ${request.id} not found');
    }

    return GetSettingQueryResponse(
      id: settings.id,
      createdDate: settings.createdDate,
      modifiedDate: settings.modifiedDate,
      key: settings.key,
      value: settings.value,
      valueType: settings.valueType,
    );
  }
}
