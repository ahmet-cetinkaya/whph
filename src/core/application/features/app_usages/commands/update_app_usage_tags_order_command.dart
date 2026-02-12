import 'package:mediatr/mediatr.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';

class UpdateAppUsageTagsOrderCommand implements IRequest<void> {
  final String appUsageId;
  final Map<String, int> tagOrders;

  UpdateAppUsageTagsOrderCommand({
    required this.appUsageId,
    required this.tagOrders,
  });
}

class UpdateAppUsageTagsOrderCommandHandler implements IRequestHandler<UpdateAppUsageTagsOrderCommand, void> {
  final IAppUsageTagRepository _appUsageTagRepository;

  UpdateAppUsageTagsOrderCommandHandler({required IAppUsageTagRepository appUsageTagRepository})
      : _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<void> call(UpdateAppUsageTagsOrderCommand request) async {
    await _appUsageTagRepository.updateTagOrders(request.appUsageId, request.tagOrders);
  }
}
