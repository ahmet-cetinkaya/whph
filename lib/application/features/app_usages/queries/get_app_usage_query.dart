import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/constants/app_usage_translation_keys.dart';

class GetAppUsageQuery implements IRequest<GetAppUsageQueryResponse> {
  late String id;

  GetAppUsageQuery({required this.id});
}

class GetAppUsageQueryResponse {
  String name;
  String? displayName;
  String? color;
  String? deviceName;

  GetAppUsageQueryResponse({
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
  });
}

class GetAppUsageQueryHandler implements IRequestHandler<GetAppUsageQuery, GetAppUsageQueryResponse> {
  late final IAppUsageRepository _appUsageRepository;

  GetAppUsageQueryHandler({required IAppUsageRepository appUsageRepository}) : _appUsageRepository = appUsageRepository;

  @override
  Future<GetAppUsageQueryResponse> call(GetAppUsageQuery request) async {
    AppUsage? appUsages = await _appUsageRepository.getById(request.id);
    if (appUsages == null) {
      throw BusinessException('App usage not found', AppUsageTranslationKeys.appUsageNotFoundError);
    }

    return GetAppUsageQueryResponse(
      name: appUsages.name,
      displayName: appUsages.displayName,
      color: appUsages.color,
      deviceName: appUsages.deviceName,
    );
  }
}
