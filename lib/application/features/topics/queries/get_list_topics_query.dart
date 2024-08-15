import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/topic/topic.dart';

class GetListTopicsQuery implements IRequest<GetListTopicsQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListTopicsQuery({required this.pageIndex, required this.pageSize});
}

class GetListTopicsQueryResponse extends PaginatedList<Topic> {
  GetListTopicsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTopicsQueryHandler implements IRequestHandler<GetListTopicsQuery, GetListTopicsQueryResponse> {
  late final ITopicRepository _topicRepository;

  GetListTopicsQueryHandler({required ITopicRepository topicRepository}) : _topicRepository = topicRepository;

  @override
  Future<GetListTopicsQueryResponse> call(GetListTopicsQuery request) async {
    PaginatedList<Topic> topics = await _topicRepository.getList(
      request.pageIndex,
      request.pageSize,
    );

    return GetListTopicsQueryResponse(
      items: topics.items,
      totalItemCount: topics.totalItemCount,
      totalPageCount: topics.totalPageCount,
      pageIndex: topics.pageIndex,
      pageSize: topics.pageSize,
    );
  }
}
