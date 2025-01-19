import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';

class SaveAppUsageCommand implements IRequest<SaveAppUsageCommandResponse> {
  final String? id;
  final String name;
  final String? displayName;
  final String? color;

  SaveAppUsageCommand({
    this.id,
    required this.name,
    this.displayName,
    this.color,
  });
}

class SaveAppUsageCommandResponse {
  final String id;
  final String name;
  final String? displayName;
  final String? color;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveAppUsageCommandResponse({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
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
        throw BusinessException('App Usage with id ${request.id} not found');
      }

      appUsage.displayName = request.displayName;
      appUsage.color = request.color;
      await _appUsageRepository.update(appUsage);
    } else {
      appUsage = AppUsage(
        id: nanoid(),
        name: request.name,
        displayName: request.displayName,
        color: request.color,
        createdDate: DateTime(0),
      );
      await _appUsageRepository.add(appUsage);
    }

    return SaveAppUsageCommandResponse(
      id: appUsage.id,
      name: appUsage.name,
      displayName: appUsage.displayName,
      color: appUsage.color,
      createdDate: appUsage.createdDate,
      modifiedDate: appUsage.modifiedDate,
    );
  }
}
