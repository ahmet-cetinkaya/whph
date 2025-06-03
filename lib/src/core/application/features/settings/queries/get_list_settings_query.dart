import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';

class GetListSettingsQuery implements IRequest<GetListSettingsQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListSettingsQuery({required this.pageIndex, required this.pageSize});
}

class SettingListItem {
  String id;
  String key;
  String value;
  SettingValueType valueType;

  SettingListItem({required this.id, required this.key, required this.value, required this.valueType});
}

class GetListSettingsQueryResponse extends PaginatedList<SettingListItem> {
  GetListSettingsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListSettingsQueryHandler implements IRequestHandler<GetListSettingsQuery, GetListSettingsQueryResponse> {
  late final ISettingRepository _settingRepository;

  GetListSettingsQueryHandler({required ISettingRepository settingRepository}) : _settingRepository = settingRepository;

  @override
  Future<GetListSettingsQueryResponse> call(GetListSettingsQuery request) async {
    PaginatedList<Setting> settings = await _settingRepository.getList(
      request.pageIndex,
      request.pageSize,
    );

    return GetListSettingsQueryResponse(
      items: settings.items
          .map((e) => SettingListItem(id: e.id, key: e.key, value: e.value, valueType: e.valueType))
          .toList(),
      totalItemCount: settings.totalItemCount,
      pageIndex: settings.pageIndex,
      pageSize: settings.pageSize,
    );
  }
}
