import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/constants/app_usage_translation_keys.dart';

class SaveAppUsageCommand implements IRequest<SaveAppUsageCommandResponse> {
  final String? id;
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;

  SaveAppUsageCommand({
    this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
  });
}

class SaveAppUsageCommandResponse {
  final String id;
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveAppUsageCommandResponse({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveAppUsageCommandHandler implements IRequestHandler<SaveAppUsageCommand, SaveAppUsageCommandResponse> {
  final IAppUsageRepository _appUsageRepository;

  SaveAppUsageCommandHandler({required IAppUsageRepository appUsageRepository})
      : _appUsageRepository = appUsageRepository;

  @override
  Future<SaveAppUsageCommandResponse> call(SaveAppUsageCommand request) async {
    AppUsage? appUsage;

    if (request.id != null) {
      appUsage = await _appUsageRepository.getById(request.id!);
      if (appUsage == null) {
        throw BusinessException(AppUsageTranslationKeys.appUsageNotFoundError);
      }

      appUsage.displayName = request.displayName;
      appUsage.color = request.color;
      appUsage.deviceName = request.deviceName;
      await _appUsageRepository.update(appUsage);
    } else {
      appUsage = AppUsage(
        id: nanoid(),
        name: request.name,
        displayName: request.displayName,
        color: request.color,
        deviceName: request.deviceName,
        createdDate: DateTime.now(),
      );
      await _appUsageRepository.add(appUsage);
    }

    return SaveAppUsageCommandResponse(
      id: appUsage.id,
      name: appUsage.name,
      displayName: appUsage.displayName,
      color: appUsage.color,
      deviceName: appUsage.deviceName,
      createdDate: appUsage.createdDate,
      modifiedDate: appUsage.modifiedDate,
    );
  }
}
