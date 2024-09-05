import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';

class AddAppUsageTagCommand implements IRequest<AddAppUsageTagCommandResponse> {
  String appUsageId;
  int tagId;

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
      throw Exception('App usage tag already exists');
    }

    var appUsageTag = AppUsageTag(
      id: '',
      createdDate: DateTime(0),
      appUsageId: request.appUsageId,
      tagId: request.tagId,
    );
    await _appUsageTagRepository.add(appUsageTag);

    return AddAppUsageTagCommandResponse(
      id: appUsageTag.id,
    );
  }
}
