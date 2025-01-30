import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';

class AddAppUsageTagCommand implements IRequest<AddAppUsageTagCommandResponse> {
  String appUsageId;
  String tagId;

  AddAppUsageTagCommand({
    required this.appUsageId,
    required this.tagId,
  });
}

class AddAppUsageTagCommandResponse {
  final String id;

  AddAppUsageTagCommandResponse({
    required this.id,
  });
}

class AddAppUsageTagCommandHandler implements IRequestHandler<AddAppUsageTagCommand, AddAppUsageTagCommandResponse> {
  final IAppUsageTagRepository _appUsageTagRepository;

  AddAppUsageTagCommandHandler({required IAppUsageTagRepository appUsageTagRepository})
      : _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<AddAppUsageTagCommandResponse> call(AddAppUsageTagCommand request) async {
    if (await _appUsageTagRepository.anyByAppUsageIdAndTagId(request.appUsageId, request.tagId)) {
      throw BusinessException('App usage tag already exists');
    }

    final appUsageTag = AppUsageTag(
      id: nanoid(),
      createdDate: DateTime.now(),
      appUsageId: request.appUsageId,
      tagId: request.tagId,
    );
    await _appUsageTagRepository.add(appUsageTag);

    return AddAppUsageTagCommandResponse(
      id: appUsageTag.id,
    );
  }
}
