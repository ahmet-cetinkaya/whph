import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/domain/features/topic/topic.dart';

class GetTopicsQuery implements IRequest<GetTopicsQueryResponse> {
  late int id;

  GetTopicsQuery({required this.id});
}

class GetTopicsQueryResponse extends Topic {
  GetTopicsQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    required super.parentId,
    required super.name,
  });
}

class GetTopicsQueryHandler implements IRequestHandler<GetTopicsQuery, GetTopicsQueryResponse> {
  late final ITopicRepository _topicRepository;

  GetTopicsQueryHandler({required ITopicRepository topicRepository}) : _topicRepository = topicRepository;

  @override
  Future<GetTopicsQueryResponse> call(GetTopicsQuery request) async {
    Topic? topics = await _topicRepository.getById(
      request.id,
    );
    if (topics == null) {
      throw Exception('Topic with id ${request.id} not found');
    }

    return GetTopicsQueryResponse(
      id: topics.id,
      createdDate: topics.createdDate,
      modifiedDate: topics.modifiedDate,
      parentId: topics.parentId,
      name: topics.name,
    );
  }
}
