import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/domain/features/topic/topic.dart';

class DeleteTopicCommand implements IRequest<DeleteTopicCommandResponse> {
  final int id;

  DeleteTopicCommand({required this.id});
}

class DeleteTopicCommandResponse {}

class DeleteTopicCommandHandler implements IRequestHandler<DeleteTopicCommand, DeleteTopicCommandResponse> {
  final ITopicRepository _topicRepository;

  DeleteTopicCommandHandler({required ITopicRepository topicRepository}) : _topicRepository = topicRepository;

  @override
  Future<DeleteTopicCommandResponse> call(DeleteTopicCommand request) async {
    Topic? topic = await _topicRepository.getById(request.id);
    if (topic == null) {
      throw Exception('Topic with id ${request.id} not found');
    }

    await _topicRepository.delete(topic.id);

    return DeleteTopicCommandResponse();
  }
}
