import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/constants/app_usage_translation_keys.dart';

class DeleteAppUsageCommand implements IRequest<DeleteAppUsageCommandResponse> {
  final String id;

  DeleteAppUsageCommand({required this.id});
}

class DeleteAppUsageCommandResponse {
  final String id;
  final DateTime deletedDate;

  DeleteAppUsageCommandResponse({required this.id, required this.deletedDate});
}

class DeleteAppUsageCommandHandler implements IRequestHandler<DeleteAppUsageCommand, DeleteAppUsageCommandResponse> {
  final IAppUsageRepository _appUsageRepository;

  DeleteAppUsageCommandHandler({required IAppUsageRepository appUsageRepository})
      : _appUsageRepository = appUsageRepository;

  @override
  Future<DeleteAppUsageCommandResponse> call(DeleteAppUsageCommand request) async {
    AppUsage? appUsage = await _appUsageRepository.getById(request.id);
    if (appUsage == null) {
      throw BusinessException(AppUsageTranslationKeys.appUsageNotFoundError);
    }

    await _appUsageRepository.delete(appUsage);

    return DeleteAppUsageCommandResponse(
      id: appUsage.id,
      deletedDate: appUsage.deletedDate!,
    );
  }
}
