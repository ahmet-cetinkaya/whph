import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:whph/core/application/features/app_usages/constants/app_usage_translation_keys.dart';

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
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;

  DeleteAppUsageCommandHandler({
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTagRepository appUsageTagRepository,
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
  })  : _appUsageRepository = appUsageRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository;

  @override
  Future<DeleteAppUsageCommandResponse> call(DeleteAppUsageCommand request) async {
    AppUsage? appUsage = await _appUsageRepository.getById(request.id);
    if (appUsage == null) {
      throw BusinessException('App usage not found', AppUsageTranslationKeys.appUsageNotFoundError);
    }

    // Cascade delete: Delete all related entities first
    await _deleteRelatedEntities(request.id);

    // Delete the app usage itself
    await _appUsageRepository.delete(appUsage);

    return DeleteAppUsageCommandResponse(
      id: appUsage.id,
      deletedDate: appUsage.deletedDate!,
    );
  }

  /// Deletes all entities related to the app usage
  Future<void> _deleteRelatedEntities(String appUsageId) async {
    // Delete app usage tags
    final appUsageTags = await _appUsageTagRepository.getListByAppUsageId(appUsageId, 0, 1000);
    for (final appUsageTag in appUsageTags.items) {
      await _appUsageTagRepository.delete(appUsageTag);
    }

    // Delete app usage time records
    final appUsageTimeRecords = await _appUsageTimeRecordRepository.getByAppUsageId(appUsageId);
    for (final appUsageTimeRecord in appUsageTimeRecords) {
      await _appUsageTimeRecordRepository.delete(appUsageTimeRecord);
    }
  }
}
