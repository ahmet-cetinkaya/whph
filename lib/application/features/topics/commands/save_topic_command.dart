import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/domain/features/topic/topic.dart';

class SaveTopicCommand implements IRequest<SaveTopicCommandResponse> {
  final int? id;
  final int? parentId;
  final String name;

  SaveTopicCommand({
    this.id,
    this.parentId,
    required this.name,
  });
}

class SaveTopicCommandResponse {
  final int id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveTopicCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveTopicCommandHandler implements IRequestHandler<SaveTopicCommand, SaveTopicCommandResponse> {
  final ITopicRepository _topicRepository;

  SaveTopicCommandHandler({required ITopicRepository topicRepository}) : _topicRepository = topicRepository;

  @override
  Future<SaveTopicCommandResponse> call(SaveTopicCommand request) async {
    Topic? topic;

    if (request.id != null) {
      topic = await _topicRepository.getById(request.id!);
      if (topic == null) {
        throw Exception('Topic with id ${request.id} not found');
      }

      topic.parentId = request.parentId;
      topic.name = request.name;
      await _topicRepository.update(topic);
    } else {
      topic = Topic(
        id: 0,
        createdDate: DateTime(0),
        parentId: request.parentId,
        name: request.name,
      );
      await _topicRepository.add(topic);
    }

    return SaveTopicCommandResponse(
      id: topic.id,
      createdDate: topic.createdDate,
      modifiedDate: topic.modifiedDate,
    );
  }
}
