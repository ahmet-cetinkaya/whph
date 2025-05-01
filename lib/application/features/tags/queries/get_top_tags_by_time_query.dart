import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';

class GetTopTagsByTimeQuery implements IRequest<GetTopTagsByTimeQueryResponse> {
  final DateTime startDate;
  final DateTime endDate;
  final int? limit;
  final List<String>? filterByTags;
  final bool filterByIsArchived;

  GetTopTagsByTimeQuery({
    required this.startDate,
    required this.endDate,
    this.limit,
    this.filterByTags,
    this.filterByIsArchived = false,
  });
}

class GetTopTagsByTimeQueryResponse {
  final List<TagTimeData> items;
  final int totalDuration;

  GetTopTagsByTimeQueryResponse({
    required this.items,
    required this.totalDuration,
  });
}

class GetTopTagsByTimeQueryHandler implements IRequestHandler<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse> {
  final IAppUsageTagRepository _appUsageTagRepository;

  GetTopTagsByTimeQueryHandler({
    required IAppUsageTagRepository appUsageTagRepository,
  }) : _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<GetTopTagsByTimeQueryResponse> call(GetTopTagsByTimeQuery request) async {
    final tagTimes = await _appUsageTagRepository.getTopTagsByDuration(
      request.startDate,
      request.endDate,
      limit: request.limit,
      filterByTags: request.filterByTags,
      filterByIsArchived: request.filterByIsArchived,
    );

    final totalDuration = tagTimes.fold<int>(0, (sum, item) => sum + item.duration);

    return GetTopTagsByTimeQueryResponse(
      items: tagTimes,
      totalDuration: totalDuration,
    );
  }
}
