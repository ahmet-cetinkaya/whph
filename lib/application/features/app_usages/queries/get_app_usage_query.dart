import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';

class GetAppUsageQuery implements IRequest<GetAppUsageQueryResponse> {
  late String id;

  GetAppUsageQuery({required this.id});
}

class GetAppUsageQueryResponse {
  String name;
  String? displayName;
  int duration;
  String? color;

  GetAppUsageQueryResponse({
    required this.name,
    this.displayName,
    required this.duration,
    this.color,
  });
}

class GetAppUsageQueryHandler implements IRequestHandler<GetAppUsageQuery, GetAppUsageQueryResponse> {
  late final IAppUsageRepository _appUsageRepository;

  GetAppUsageQueryHandler({required IAppUsageRepository appUsageRepository}) : _appUsageRepository = appUsageRepository;

  @override
  Future<GetAppUsageQueryResponse> call(GetAppUsageQuery request) async {
    AppUsage? appUsages = await _appUsageRepository.getById(
      request.id,
    );
    if (appUsages == null) {
      throw BusinessException('AppUsage with id ${request.id} not found');
    }

    return GetAppUsageQueryResponse(
      name: appUsages.name,
      displayName: appUsages.displayName,
      duration: appUsages.duration,
      color: appUsages.color,
    );
  }
}
