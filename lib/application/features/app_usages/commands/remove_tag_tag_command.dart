import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/application/features/app_usages/constants/app_usage_translation_keys.dart';

class RemoveAppUsageTagCommand implements IRequest<RemoveAppUsageTagCommandResponse> {
  String id;

  RemoveAppUsageTagCommand({
    required this.id,
  });
}

class RemoveAppUsageTagCommandResponse {
  final String id;

  RemoveAppUsageTagCommandResponse({
    required this.id,
  });
}

class RemoveAppUsageTagCommandHandler
    implements IRequestHandler<RemoveAppUsageTagCommand, RemoveAppUsageTagCommandResponse> {
  final IAppUsageTagRepository _appUsageTagRepository;

  RemoveAppUsageTagCommandHandler({required IAppUsageTagRepository appUsageTagRepository})
      : _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<RemoveAppUsageTagCommandResponse> call(RemoveAppUsageTagCommand request) async {
    AppUsageTag? appUsageTag = await _appUsageTagRepository.getById(request.id);
    if (appUsageTag == null) {
      throw BusinessException(AppUsageTranslationKeys.appUsageTagNotFoundError);
    }
    await _appUsageTagRepository.delete(appUsageTag);

    return RemoveAppUsageTagCommandResponse(
      id: appUsageTag.id,
    );
  }
}
